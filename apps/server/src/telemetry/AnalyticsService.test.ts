import * as NodeCrypto from "@effect/platform-node/NodeCrypto";
import * as NodeServices from "@effect/platform-node/NodeServices";
import { assert, it } from "@effect/vitest";
import * as ConfigProvider from "effect/ConfigProvider";
import * as Effect from "effect/Effect";
import * as Layer from "effect/Layer";
import * as HttpClient from "effect/http/HttpClient";
import * as HttpClientResponse from "effect/http/HttpClientResponse";
import * as HostProcess from "@t3tools/shared/HostProcess";

import * as ServerConfig from "../config.ts";
import * as ManagedPolicy from "../policy/ManagedPolicy.ts";
import * as AnalyticsService from "./AnalyticsService.ts";

it.layer(Layer.mergeAll(NodeServices.layer, NodeCrypto.layer))(
  "AICall zero-telemetry service",
  (it) => {
    it.effect(
      "drops all events and performs zero HTTP requests even if env enables telemetry",
      () =>
        Effect.gen(function* () {
          let requests = 0;
          const client = HttpClient.make((request) => {
            requests += 1;
            return Effect.succeed(
              HttpClientResponse.fromWeb(request, new Response(null, { status: 204 })),
            );
          });

          const layer = AnalyticsService.layer.pipe(
            Layer.provideMerge(
              ServerConfig.ServerConfig.layerTest(process.cwd(), { prefix: "aicall-telemetry-" }),
            ),
            Layer.provide(
              ConfigProvider.layer(
                ConfigProvider.fromUnknown({
                  T3CODE_TELEMETRY_ENABLED: true,
                  T3CODE_POSTHOG_KEY: "phc_test_key",
                  T3CODE_POSTHOG_HOST: "http://localhost",
                }),
              ),
            ),
            Layer.provide(
              Layer.mergeAll(
                Layer.succeed(HostProcess.Platform, "darwin"),
                Layer.succeed(HostProcess.Architecture, "arm64"),
                Layer.succeed(HttpClient.HttpClient, client),
                ManagedPolicy.layerTest(),
              ),
            ),
          );

          yield* Effect.gen(function* () {
            const analytics = yield* AnalyticsService.AnalyticsService;
            const queued = yield* analytics.record("test.event", { foo: "bar" });
            yield* analytics.recordOwners(
              [{ source: "openai", ownerId: "a".repeat(64) }],
              "server",
            );
            yield* analytics.flush;
            assert.isFalse(queued);
          }).pipe(Effect.provide(layer));

          assert.equal(requests, 0);
        }),
    );
  },
);
