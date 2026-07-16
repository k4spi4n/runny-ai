/// Small transport-neutral response used by services that invoke Supabase Edge
/// Functions. Keeping this type independent from the SDK makes the policy and
/// error handling deterministic in unit tests.
class EdgeFunctionResult {
  const EdgeFunctionResult({required this.status, this.data});

  final int status;
  final Object? data;
}
