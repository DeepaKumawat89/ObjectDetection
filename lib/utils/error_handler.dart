import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ErrorHandler {
  const ErrorHandler._();

  /// Translates technical exceptions into clean, user-friendly messages.
  static String getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      return _parseFirebaseAuthException(error);
    }

    if (error is DioException) {
      return _parseDioException(error);
    }

    if (error is CameraException) {
      return _parseCameraException(error);
    }

    if (error is SocketException) {
      return 'Unable to connect. Please check your internet connection and try again.';
    }

    if (error is TimeoutException) {
      return 'The request timed out. Please check your internet connection and try again.';
    }

    if (error is String) {
      return error.trim().isNotEmpty ? error : 'Unable to log in. Please contact the provider for assistance.';
    }

    final message = error?.toString() ?? '';
    if (message.contains('SocketException') || message.contains('Failed host lookup')) {
      return 'No internet connection. Please check your network connection and try again.';
    }

    if (message.contains('TimeoutException')) {
      return 'The operation timed out. Please try again.';
    }

    return 'Unable to log in. Please contact the provider for assistance.';
  }

  static String _parseFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-email':
        return 'Unable to log in. Please contact the provider for assistance.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support for assistance.';
      case 'too-many-requests':
        return 'Too many unsuccessful login attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network connection failed. Please check your internet connection and try again.';
      case 'operation-not-allowed':
        return 'Email/Password sign-in is not enabled. Please contact support.';
      case 'email-already-in-use':
        return 'An account already exists for this email address.';
      case 'weak-password':
        return 'The password provided is too weak. Please use a stronger password.';
      default:
        return 'Unable to log in. Please contact the provider for assistance.';
    }
  }

  static String _parseDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timed out. Please check your internet connection and try again.';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode == 401 || statusCode == 403) {
          return 'Access denied. Please sign in again or check your permissions.';
        } else if (statusCode == 404) {
          return 'The requested resource could not be found.';
        } else if (statusCode != null && statusCode >= 500) {
          return 'Server error ($statusCode). Please try again later.';
        }
        return 'Unable to process server response. Please try again later.';
      case DioExceptionType.connectionError:
        return 'No internet connection. Please check your network settings and try again.';
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      default:
        if (e.error is SocketException) {
          return 'Unable to connect to server. Please check your internet connection.';
        }
        return 'Network request failed. Please try again.';
    }
  }

  static String _parseCameraException(CameraException e) {
    switch (e.code) {
      case 'CameraAccessDenied':
      case 'cameraPermission':
        return 'Camera permission was denied. Please grant camera permission in app settings.';
      case 'CameraAccessDeniedWithoutPrompt':
        return 'Camera permission is required. Please enable camera access in app settings.';
      case 'CameraAccessRestricted':
        return 'Camera access is restricted on this device.';
      default:
        final desc = e.description?.trim();
        if (desc != null && desc.isNotEmpty) {
          return 'Camera error: $desc';
        }
        return 'Unable to access the camera. Please restart the app or check device permissions.';
    }
  }
}
