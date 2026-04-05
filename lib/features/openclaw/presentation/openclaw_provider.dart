import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/gateway_config_repository.dart';
import '../data/gateway_repository.dart';
import '../data/gateway_ws_service.dart';
import '../domain/agent_job.dart';
import '../domain/chat_session.dart';
import '../domain/gateway_connection.dart';

// ── 基础服务 Providers ───────────────────────────────────────────────

final gatewayWsServiceProvider = ChangeNotifierProvider<GatewayWsService>((ref) {
  final svc = GatewayWsService();
  ref.onDispose(svc.dispose);
  return svc;
});

final gatewayConfigRepoProvider =
    Provider<GatewayConfigRepository>((_) => GatewayConfigRepository());

final gatewayRepositoryProvider = Provider<GatewayRepository>((ref) {
  return GatewayRepository(ref.read(gatewayWsServiceProvider));
});

// ── 配置持久化 Provider ──────────────────────────────────────────────

final savedGatewayConfigProvider =
    AsyncNotifierProvider<SavedGatewayConfigNotifier, GatewayConfig?>(
  SavedGatewayConfigNotifier.new,
);

class SavedGatewayConfigNotifier extends AsyncNotifier<GatewayConfig?> {
  @override
  Future<GatewayConfig?> build() async {
    final repo = ref.read(gatewayConfigRepoProvider);
    final cfg = await repo.load();
    if (cfg != null) {
      // 启动时自动重连
      ref.read(gatewayWsServiceProvider).connect(cfg);
    }
    return cfg;
  }

  Future<void> save(GatewayConfig config) async {
    final repo = ref.read(gatewayConfigRepoProvider);
    await repo.save(config);
    state = AsyncData(config);
    await ref.read(gatewayWsServiceProvider).connect(config);
  }

  Future<void> clear() async {
    final repo = ref.read(gatewayConfigRepoProvider);
    await repo.clear();
    ref.read(gatewayWsServiceProvider).disconnect();
    state = const AsyncData(null);
  }
}

// ── 会话列表 Provider ────────────────────────────────────────────────

final sessionListProvider =
    AsyncNotifierProvider<SessionListNotifier, List<ChatSession>>(
  SessionListNotifier.new,
);

class SessionListNotifier extends AsyncNotifier<List<ChatSession>> {
  @override
  Future<List<ChatSession>> build() async {
    return ref.read(gatewayRepositoryProvider).listSessions();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(gatewayRepositoryProvider).listSessions());
  }

  Future<ChatSession> createSession({String? agentId}) async {
    final session = await ref
        .read(gatewayRepositoryProvider)
        .createSession(agentId: agentId);
    state = AsyncData([session, ...(state.valueOrNull ?? [])]);
    return session;
  }

  Future<void> deleteSession(String sessionKey) async {
    await ref.read(gatewayRepositoryProvider).deleteSession(sessionKey);
    state = AsyncData(
      (state.valueOrNull ?? [])
          .where((s) => s.key != sessionKey)
          .toList(),
    );
  }
}

// ── Agent 任务列表（内存缓存，最近50条）─────────────────────────────

final agentJobListProvider =
    NotifierProvider<AgentJobListNotifier, List<AgentJob>>(
  AgentJobListNotifier.new,
);

class AgentJobListNotifier extends Notifier<List<AgentJob>> {
  @override
  List<AgentJob> build() => [];

  void add(AgentJob job) {
    state = [job, ...state];
    if (state.length > 50) state = state.sublist(0, 50);
  }

  void update(String runId, AgentJob Function(AgentJob) updater) {
    state = state
        .map((j) => j.runId == runId ? updater(j) : j)
        .toList();
  }
}

// ── Agent 运行（发起任务）────────────────────────────────────────────

class AgentRunner {
  final Ref _ref;
  AgentRunner(this._ref);

  Future<AgentJob> run({
    required String message,
    String? agentId,
    String? model,
    String? thinking,
  }) async {
    final repo = _ref.read(gatewayRepositoryProvider);
    final runId = await repo.runAgent(
      message: message,
      agentId: agentId,
      model: model,
      thinking: thinking,
    );
    final job = AgentJob(
      runId: runId,
      status: AgentJobStatus.running,
      prompt: message,
      agentId: agentId,
      model: model,
      startedAt: DateTime.now(),
    );
    _ref.read(agentJobListProvider.notifier).add(job);
    _pollJob(runId, repo);
    return job;
  }

  void _pollJob(String runId, GatewayRepository repo) async {
    try {
      final result = await repo.waitAgent(runId);
      final statusStr = result['status'] as String? ?? '';
      final status = statusStr == 'ok'
          ? AgentJobStatus.ok
          : statusStr == 'timeout'
              ? AgentJobStatus.timeout
              : AgentJobStatus.error;
      _ref.read(agentJobListProvider.notifier).update(runId, (j) => j.copyWith(
            status: status,
            endedAt: DateTime.now(),
            errorMessage: result['error'] as String?,
            sessionKey: result['sessionKey'] as String?,
          ));
    } catch (e) {
      _ref.read(agentJobListProvider.notifier).update(runId, (j) => j.copyWith(
            status: AgentJobStatus.error,
            endedAt: DateTime.now(),
            errorMessage: e.toString(),
          ));
    }
  }
}

final agentRunnerProvider = Provider<AgentRunner>((ref) => AgentRunner(ref));

// ── 可用 Agents / Models Provider ────────────────────────────────────

final agentsListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.read(gatewayRepositoryProvider).listAgents();
});

final modelsListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.read(gatewayRepositoryProvider).listModels();
});

// ── 平台字符串 ────────────────────────────────────────────────────────

String get currentPlatform => Platform.isIOS ? 'ios' : 'android';
