/// Kết quả của một request POST dạng streaming: mã trạng thái + luồng byte thô
/// của body. Bên gọi tự giải mã UTF-8 và tách SSE. Dùng chung cho cả hai bản
/// hiện thực (web fetch / native http) qua conditional import.
class HttpStreamResult {
  final int statusCode;
  final Stream<List<int>> stream;

  const HttpStreamResult(this.statusCode, this.stream);
}
