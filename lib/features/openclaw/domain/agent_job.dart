enum AgentJobStatus { running, ok, error, timeout, unknown }

class AgentJob {
  final String runId;
  final AgentJobStatus status;
  final String prompt;
  final String? agentId;
  final String? model;
  final String? sessionKey;
  final String? errorMessage;
  final DateTime startedAt;
  final DateTime? endedAt;

  const AgentJob({
    required this.runId,
    required this.status,
    required this.prompt,
    this.agentId,
    this.model,
    this.sessionKey,
    this.errorMessage,
    required this.startedAt,
    this.endedAt,
  });

  Duration? get elapsed => endedAt?.difference(startedAt);

  AgentJob copyWith({
    AgentJobStatus? status,
    String? errorMessage,
    DateTime? endedAt,
    String? sessionKey,
  }) =>
      AgentJob(
        runId: runId,
        status: status ?? this.status,
        prompt: prompt,
        agentId: agentId,
        model: model,
        sessionKey: sessionKey ?? this.sessionKey,
        errorMessage: errorMessage ?? this.errorMessage,
        startedAt: startedAt,
        endedAt: endedAt ?? this.endedAt,
      );
}
