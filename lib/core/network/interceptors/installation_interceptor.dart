import 'package:dio/dio.dart';
import '../../services/installation_service.dart';

class InstallationInterceptor extends Interceptor {
  static const String installationHeaderKey = 'X-Installation-UUID';
  static const String clientHeaderKey = 'X-App-Client';
  static const String clientVersion = 'UR-Heart-Flutter-v1.0';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final uuid = await InstallationService.instance.getOrCreateInstallationUuid();
    options.headers[installationHeaderKey] = uuid;
    options.headers[clientHeaderKey] = clientVersion;
    return handler.next(options);
  }
}
