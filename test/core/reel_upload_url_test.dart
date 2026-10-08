import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/features/reels/reel_upload.dart';

void main() {
  const apiBase = 'http://10.0.2.2:8000/api/v1';

  test('rewrites localhost signed PUT URLs onto the API origin', () {
    final resolved = resolveReelUploadUrl(
      'http://localhost:8000/api/v1/uploads/01hupload/content?expires=1&signature=abc',
      apiBase,
    );
    expect(resolved.scheme, 'http');
    expect(resolved.host, '10.0.2.2');
    expect(resolved.port, 8000);
    expect(resolved.path, '/api/v1/uploads/01hupload/content');
    expect(resolved.queryParameters['signature'], 'abc');
  });

  test('keeps Mux GCS direct-upload URLs on their original host', () {
    const mux =
        'https://storage.googleapis.com/mux-uploads/abc?X-Goog-Algorithm=GOOG4-RSA-SHA256';
    expect(resolveReelUploadUrl(mux, apiBase).toString(), mux);
  });

  test('keeps object-storage PUT URLs on their original host', () {
    const s3 =
        'https://pelevo-media.s3.eu-central-1.amazonaws.com/reel-uploads/1/file'
        '?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Signature=deadbeef';
    expect(resolveReelUploadUrl(s3, apiBase).toString(), s3);
  });

  test('resolves relative local PUT paths against the API origin', () {
    final resolved = resolveReelUploadUrl(
      '/api/v1/uploads/01hupload/content?expires=1&signature=abc',
      apiBase,
    );
    expect(resolved.origin, 'http://10.0.2.2:8000');
    expect(resolved.path, '/api/v1/uploads/01hupload/content');
  });
}
