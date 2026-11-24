import * as NodeCrypto from "@effect/platform-node/NodeCrypto";
import * as NodeServices from "@effect/platform-node/NodeServices";
import { assert, it } from "@effect/vitest";
import * as Effect from "effect/Effect";
import * as FileSystem from "effect/FileSystem";
import * as Layer from "effect/Layer";
import * as Path from "effect/Path";

import * as ServerSecretStore from "../auth/ServerSecretStore.ts";
import { CLOUD_LINKED_USER_ID } from "../cloud/config.ts";
import * as ServerConfig from "../config.ts";
import * as Identify from "./Identify.ts";

const layerIdentity = (prefix: string) =>
  Layer.provideMerge(ServerSecretStore.layer, ServerConfig.layerTest(process.cwd(), { prefix }));

it.layer(Layer.mergeAll(NodeServices.layer, NodeCrypto.layer))(
  "AICall zero-telemetry identity",
  (it) => {
    it.effect(
      "never reads ~/.codex/auth.json or ~/.claude.json and never writes anonymous-id",
      () =>
        Effect.gen(function* () {
          const config = yield* ServerConfig.ServerConfig;
          const secrets = yield* ServerSecretStore.ServerSecretStore;
          const fileSystem = yield* FileSystem.FileSystem;
          const path = yield* Path.Path;
          const homeDirectory = path.join(config.baseDir, "home");

          yield* fileSystem.makeDirectory(path.join(homeDirectory, ".codex"), { recursive: true });
          yield* fileSystem.writeFileString(
            path.join(homeDirectory, ".codex", "auth.json"),
            `{"tokens":{"account_id":"ws-1"}}`,
          );
          yield* fileSystem.writeFileString(
            path.join(homeDirectory, ".claude.json"),
            `{"userID":"claude-machine","oauthAccount":{"accountUuid":"claude-person"}}`,
          );
          yield* secrets.set(CLOUD_LINKED_USER_ID, new TextEncoder().encode("user_connect"));

          const identity = yield* Identify.getTelemetryIdentityForHome(homeDirectory);
          const owners = yield* Identify.getServerOwnersForHome(homeDirectory);

          assert.deepEqual(identity, { distinctId: null, installId: null });
          assert.deepEqual(owners, []);
          assert.isFalse(yield* fileSystem.exists(config.anonymousIdPath));
        }).pipe(Effect.provide(layerIdentity("aicall-telemetry-identify-"))),
    );
  },
);
