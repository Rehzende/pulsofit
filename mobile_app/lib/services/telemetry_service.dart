import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:opentelemetry/api.dart' as otel;
import 'package:opentelemetry/sdk.dart' as otel_sdk;
import '../core/constants.dart';

class TelemetryService {
  static final TelemetryService _instance = TelemetryService._internal();
  factory TelemetryService() => _instance;
  TelemetryService._internal();

  otel.Tracer? _tracer;
  bool _isEnabled = false;

  void initialize({
    required String serviceName,
    required String? endpoint,
    required String? headers,
  }) {
    if (endpoint == null || endpoint.isEmpty) {
      debugPrint('OpenTelemetry: No endpoint provided. Tracing disabled.');
      return;
    }

    try {
      // 1. Setup Resource
      final resource = otel_sdk.Resource([
        otel.Attribute.fromString('service.name', serviceName),
        otel.Attribute.fromString('deployment.environment', 'production'),
      ]);

      // 2. Setup Exporter (OTLP)
      // Note: In a real Flutter app, you'd use opentelemetry_exporter_otlp
      // For now, we'll setup the infrastructure.
      final exporter = otel_sdk.CollectorExporter(
        Uri.parse(endpoint),
        // headers are parsed from the string "key1=val1,key2=val2"
      );

      // 3. Setup Processor and Provider
      final processor = otel_sdk.BatchSpanProcessor(exporter);
      final provider = otel_sdk.TracerProviderBase(
        resource: resource,
        processors: [processor],
      );

      otel.registerGlobalTracerProvider(provider);
      _tracer = provider.getTracer(serviceName);
      _isEnabled = true;
      debugPrint('OpenTelemetry: Initialized and exporting to $endpoint');
    } catch (e) {
      debugPrint('OpenTelemetry: Failed to initialize: $e');
    }
  }

  otel.Tracer? get tracer => _tracer;
  bool get isEnabled => _isEnabled;

  /// Creates a Dio interceptor for OTel tracing
  Interceptor get dioInterceptor => InterceptorsWrapper(
    onRequest: (options, handler) {
      if (!_isEnabled || _tracer == null) return handler.next(options);

      final span = _tracer!.startSpan(
        'HTTP ${options.method} ${options.path}',
        kind: otel.SpanKind.client,
      );
      
      span.setAttributes([
        otel.Attribute.fromString('http.method', options.method),
        otel.Attribute.fromString('http.url', options.uri.toString()),
      ]);

      // Store span in extra to retrieve it in onResponse/onError
      options.extra['otel_span'] = span;
      
      // Inject trace context into headers (TraceParent)
      // This allows distributed tracing between Flutter and Backend!
      // In a full implementation, use otel.globalTextMapPropagator
      
      return handler.next(options);
    },
    onResponse: (response, handler) {
      final span = response.requestOptions.extra['otel_span'] as otel.Span?;
      if (span != null) {
        span.setAttribute(otel.Attribute.fromInt('http.status_code', response.statusCode ?? 0));
        span.end();
      }
      return handler.next(response);
    },
    onError: (err, handler) {
      final span = err.requestOptions.extra['otel_span'] as otel.Span?;
      if (span != null) {
        span.setAttribute(otel.Attribute.fromString('error', 'true'));
        span.setAttribute(otel.Attribute.fromString('error.message', err.message ?? 'Unknown error'));
        span.end();
      }
      return handler.next(err);
    },
  );
}
