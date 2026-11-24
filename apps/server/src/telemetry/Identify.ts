import * as SecureRandom from "effect/crypto/SecureRandom";
import * as Effect from "effect/Effect";
import * as Base64Url from "effect/encoding/Base64Url";
import * as FileSystem from "effect/FileSystem";
import * as Option from "effect/Option";
import * as Path from "effect/Path";
import * as PlatformError from "effect/PlatformError";
import * as Result from "effect/Result";
import * as Schema from "effect/Schema";

import { writeFileStringAtomically } from "@t3tools/shared/atomicWrite";
import * as HostProcess from "@t3tools/shared/HostProcess";
import { hashTelemetryId } from "@t3tools/shared/telemetryId";
import * as ServerSecretStore from "../auth/ServerSecretStore.ts";
import { CLOUD_LINKED_USER_ID } from "../cloud/config.ts";
import * as ServerConfig from "../config.ts";

/**
 * Codex writes `tokens` only for ChatGPT logins and omits the key for API-key,
 * agent-identity, and personal-access-token logins, so its absence is a
 * supported install and not a malformed file. `account_id` is the ChatGPT
 * workspace, which a whole Team shares; the `id_token` names the person.
 */
const CodexAuthJsonSchema = Schema.Struct({
  tokens: Schema.optionalKey(
    Schema.Struct({
      account_id: Schema.String,
      id_token: Schema.optionalKey(Schema.String),
    }),
  ),
});

/** `userID` is random per machine. `oauthAccount` is present only while Claude Code is logged in. */
const ClaudeJsonSchema = Schema.Struct({
  userID: Schema.optionalKey(Schema.String),
  oauthAccount: Schema.optionalKey(
    Schema.Struct({
      accountUuid: Schema.optionalKey(Schema.String),
    }),
  ),
});

// `sub` names the login method (`google-oauth2|…`), so one person can have several.
// `user_id` (`user-…`) is the OpenAI account and is the same for every login.
const IdTokenClaims = Schema.Struct({
  "https://api.openai.com/auth": Schema.Struct({ user_id: Schema.NonEmptyString }),
});
const decodeIdTokenClaims = Schema.decodeUnknownOption(Schema.fromJsonString(IdTokenClaims));

/**
 * Who an install belongs to, from strongest to weakest. `connect` is the T3
 * Connect account. `openai` and `claude` are provider accounts. `device` is a
 * client device that connected.
 */
export const TelemetryOwnerSource = Schema.Literals(["connect", "openai", "claude", "device"]);
export type TelemetryOwnerSource = typeof TelemetryOwnerSource.Type;

export interface TelemetryOwner {
  readonly source: TelemetryOwnerSource;
  /** `hashTelemetryId` of the source's raw id. */
  readonly ownerId: string;
}

export const TelemetryIdentitySource = Schema.Literals(["codex", "claude", "anonymous"]);
export type TelemetryIdentitySource = typeof TelemetryIdentitySource.Type;

class TelemetryIdentityReadError extends Schema.TaggedError<TelemetryIdentityReadError>()(
  "TelemetryIdentityReadError",
  {
    source: TelemetryIdentitySource,
    filePath: Schema.String,
    cause: Schema.Defect(),
  },
) {
  override get message(): string {
    return `Failed to read ${this.source} telemetry identity at '${this.filePath}'.`;
  }
}

class TelemetryIdentityDecodeError extends Schema.TaggedError<TelemetryIdentityDecodeError>()(
  "TelemetryIdentityDecodeError",
  {
    source: Schema.Literals(["codex", "claude"]),
    filePath: Schema.String,
    cause: Schema.Defect(),
  },
) {
  override get message(): string {
    return `Failed to decode ${this.source} telemetry identity at '${this.filePath}'.`;
  }
}

export class TelemetryAnonymousIdGenerationError extends Schema.TaggedError<TelemetryAnonymousIdGenerationError>()(
  "TelemetryAnonymousIdGenerationError",
  {
    source: Schema.Literal("anonymous"),
    filePath: Schema.String,
    cause: Schema.Defect(),
  },
) {
  override get message(): string {
    return `Failed to generate anonymous telemetry identity for '${this.filePath}'.`;
  }
}

export class TelemetryAnonymousIdPersistenceError extends Schema.TaggedError<TelemetryAnonymousIdPersistenceError>()(
  "TelemetryAnonymousIdPersistenceError",
  {
    source: Schema.Literal("anonymous"),
    filePath: Schema.String,
    cause: Schema.Defect(),
  },
) {
  override get message(): string {
    return `Failed to persist anonymous telemetry identity at '${this.filePath}'.`;
  }
}

type TelemetryIdentityError =
  | TelemetryIdentityReadError
  | TelemetryIdentityDecodeError
  | TelemetryAnonymousIdGenerationError
  | TelemetryAnonymousIdPersistenceError;

const decodeCodexAuthJson = Schema.decodeEffect(Schema.fromJsonString(CodexAuthJsonSchema));
const decodeClaudeJson = Schema.decodeEffect(Schema.fromJsonString(ClaudeJsonSchema));

function isNotFoundError(error: PlatformError.PlatformError): boolean {
  return error.reason._tag === "NotFound";
}

const getTelemetryIdentityCauseAnnotations = (cause: unknown) => {
  if (cause instanceof PlatformError.PlatformError) {
    return {
      causeKind: "platform",
      platformReason: cause.reason._tag,
    };
  }
  if (cause instanceof Schema.SchemaError) {
    return { causeKind: "schema" };
  }
  return { causeKind: "other" };
};

const logTelemetryIdentityError = (error: TelemetryIdentityError) =>
  Effect.logWarning(error.message).pipe(
    Effect.annotateLogs({
      errorTag: error._tag,
      source: error.source,
      ...("filePath" in error ? { filePath: error.filePath } : {}),
      ...getTelemetryIdentityCauseAnnotations(error.cause),
      ...(error.stack === undefined ? {} : { errorStack: error.stack }),
    }),
  );

const readIdentityFile = (
  fileSystem: FileSystem.FileSystem,
  source: TelemetryIdentitySource,
  filePath: string,
) =>
  fileSystem.readFileString(filePath).pipe(
    Effect.asSome,
    Effect.catchTags({
      PlatformError: (cause) =>
        isNotFoundError(cause)
          ? Effect.succeed(Option.none<string>())
          : Effect.fail(
              new TelemetryIdentityReadError({
                source,
                filePath,
                cause,
              }),
            ),
    }),
  );

/**
 * The OpenAI account id in a ChatGPT id_token, read without verifying it:
 * analytics needs only a stable id. Codex CLI and T3's own sign-in both use it.
 */
export const openAiUserId = (idToken: string) => {
  const payload = Base64Url.decodeString(idToken.split(".")[1] ?? "");
  return Result.isSuccess(payload)
    ? Option.map(
        decodeIdTokenClaims(payload.success),
        (claims) => claims["https://api.openai.com/auth"].user_id,
      )
    : Option.none<string>();
};

const readJsonIdentityFile = Effect.fn("TelemetryIdentity.readJsonIdentityFile")(function* <A>(
  source: "codex" | "claude",
  filePath: string,
  decode: (encoded: string) => Effect.Effect<A, Schema.SchemaError>,
) {
  const fileSystem = yield* FileSystem.FileSystem;
  const encoded = yield* readIdentityFile(fileSystem, source, filePath);
  if (Option.isNone(encoded)) {
    return Option.none<A>();
  }
  return yield* decode(encoded.value).pipe(
    Effect.asSome,
    Effect.mapError((cause) => new TelemetryIdentityDecodeError({ source, filePath, cause })),
  );
});

// A missing or unreadable file only removes that owner; it never blocks the others.
const skipOnError = <A, R>(
  effect: Effect.Effect<
    Option.Option<A>,
    TelemetryIdentityReadError | TelemetryIdentityDecodeError,
    R
  >,
) =>
  effect.pipe(
    Effect.catch((error) => logTelemetryIdentityError(error).pipe(Effect.as(Option.none<A>()))),
  );

const upsertAnonymousId = Effect.gen(function* () {
  const fileSystem = yield* FileSystem.FileSystem;
  const { anonymousIdPath } = yield* ServerConfig.ServerConfig;

  const existing = yield* readIdentityFile(fileSystem, "anonymous", anonymousIdPath);
  if (Option.isSome(existing)) {
    return existing.value;
  }

  const anonymousId = yield* SecureRandom.SecureRandom.pipe(
    Effect.flatMap((crypto) => crypto.uuidV4()),
    Effect.mapError(
      (cause) =>
        new TelemetryAnonymousIdGenerationError({
          source: "anonymous",
          filePath: anonymousIdPath,
          cause,
        }),
    ),
  );
  yield* writeFileStringAtomically({ filePath: anonymousIdPath, contents: anonymousId }).pipe(
    Effect.mapError(
      (cause) =>
        new TelemetryAnonymousIdPersistenceError({
          source: "anonymous",
          filePath: anonymousIdPath,
          cause,
        }),
    ),
  );

  return anonymousId;
});

const readProviderLogins = Effect.fn("TelemetryIdentity.readProviderLogins")(function* (
  _homeDirectory: string,
) {
  yield* Effect.void;
  void [
    Path,
    decodeCodexAuthJson,
    decodeClaudeJson,
    readJsonIdentityFile,
    skipOnError,
    upsertAnonymousId,
    hashTelemetryId,
    ServerSecretStore,
    CLOUD_LINKED_USER_ID,
  ];
  return {
    codexTokens: Option.none<{ readonly account_id: string; readonly id_token?: string }>(),
    claudeJson: Option.none<typeof ClaudeJsonSchema.Type>(),
  };
});

/**
 * Telemetry identity disabled in AICall local fork: never reads ~/.codex/auth.json,
 * ~/.claude.json, or persists ~/.t3/userdata/anonymous-id.
 */
export const getTelemetryIdentityForHome = Effect.fn("getTelemetryIdentityForHome")(function* (
  homeDirectory: string,
) {
  yield* readProviderLogins(homeDirectory);
  return {
    distinctId: null as string | null,
    installId: null as string | null,
  };
});

export const getTelemetryIdentity = Effect.flatMap(
  HostProcess.HomeDirectory,
  getTelemetryIdentityForHome,
);

/**
 * Disabled in AICall local fork: never reads linked T3 Connect or provider logins.
 */
export const getServerOwnersForHome = Effect.fn("getServerOwnersForHome")(function* (
  homeDirectory: string,
) {
  yield* readProviderLogins(homeDirectory);
  return [] as ReadonlyArray<TelemetryOwner>;
});

export const getServerOwners = Effect.flatMap(HostProcess.HomeDirectory, getServerOwnersForHome);
