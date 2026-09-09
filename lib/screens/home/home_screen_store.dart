import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobx/mobx.dart';

import '../../apibase/api_service_type.dart';
import '../../models/create_session_dm.dart';
import '../../models/create_session_links_dm.dart';
import '../../models/profile_image_dm.dart';
import '../../models/urls_dm.dart';
import '../../models/user_dm.dart';
import '../../models/user_links_dm.dart';
import '../../services/navigation_service.dart';
import '../../values/app_routes.dart';
import '../../values/enumerations.dart';

part 'home_screen_store.g.dart';

class HomeScreenStore = _HomeScreenStore with _$HomeScreenStore;

abstract class _HomeScreenStore with Store {
  @observable
  String searchQuery = 'car';

  final scrollController = ScrollController();

  final imagePicker = ImagePicker();

  @observable
  NetworkState unsplashPhotosState = NetworkState.idle;

  @observable
  NetworkState paginatedState = NetworkState.idle;

  @observable
  ObservableList<CreateSessionDm> photos = ObservableList();

  int _currentPage = 1;

  final int _totalPages = 10;

  void initialize() {
    unawaited(getUnsplashPhotos());
    scrollController.addListener(
      () {
        final maxScroll = scrollController.position.maxScrollExtent;
        final currentScroll = scrollController.position.pixels;
        if (currentScroll == maxScroll) {
          fetchMore();
        }
      },
    );
  }

  Future<void> refresh() async {
    _currentPage = 1;
    photos.clear();
    await getUnsplashPhotos();
  }

  Future<void> getUnsplashPhotos() async {
    unsplashPhotosState = NetworkState.loading;
    try {
      final result = await ApiServiceType.unsplashApiService.searchPhotos(
        page: _currentPage,
        search: searchQuery.trim(),
      );
      _currentPage++;
      photos
        ..clear()
        ..add(_cupWithTextPhoto)
        ..add(_bottlePhoto)
        ..add(_textOnImagePhoto)
        ..add(_documentTextPhoto)
        ..addAll(result.results);
      unsplashPhotosState = NetworkState.success;
    } catch (e, s) {
      log('Error getting photos from Unsplash: $e', name: 'getUnsplashPhotos()');
      log('Stacktrace: $s', name: 'getUnsplashPhotos()');
      if (photos.isEmpty) {
        photos.addAll(_fallbackPhotos);
      }
      unsplashPhotosState = NetworkState.success;
    }
  }

  Future<void> fetchMore() async {
    if (paginatedState.isLoading || _currentPage > _totalPages) return;

    paginatedState = NetworkState.loading;
    try {
      final result = await ApiServiceType.unsplashApiService.searchPhotos(
        page: _currentPage,
        search: searchQuery,
      );
      _currentPage++;
      result.results
        ..removeAt(0)
        ..removeAt(0);
      photos.addAll(result.results);
      paginatedState = NetworkState.success;
    } catch (e, s) {
      log('Error: $e', name: 'getUnsplashPhotos()');
      log('Stacktrace: $s', name: 'getUnsplashPhotos()');
      paginatedState = NetworkState.error;
    }
  }

  Future<void> analyzeNetworkImage(String url) async {
    try {
      final response = await NetworkAssetBundle(Uri.parse(url)).load(url);
      final bytes = response.buffer.asUint8List(
        response.offsetInBytes,
        response.lengthInBytes,
      );
      NavigationService.instance.pushNamed(
        AppRoutes.photoAnalyzedScreen,
        arguments: bytes,
      );
    } catch (e, s) {
      log('Error downloading network image: $e', name: 'analyzeNetworkImage()');
      log('Stacktrace: $s', name: 'analyzeNetworkImage()');
    }
  }

  Future<void> pickImageFromCamera() async {
    NavigationService.instance.pushNamed(
      AppRoutes.cameraScreen,
    );
  }

  Future<void> pickImageFromGallery() async {
    try {
      final result = await imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      if (result == null) return;
      final bytes = await result.readAsBytes();
      if (bytes.isNotEmpty) {
        NavigationService.instance.pushNamed(
          AppRoutes.photoAnalyzedScreen,
          arguments: bytes,
        );
      }
    } catch (e, s) {
      log('Error picking image from gallery: $e', name: 'pickImageFromGallery()');
      log('Stacktrace: $s', name: 'pickImageFromGallery()');
    }
  }

  static const CreateSessionDm _bottlePhoto = CreateSessionDm(
    id: 'sample_bottle_1',
    slug: 'bottle-1',
    width: 1080,
    height: 720,
    color: '#000000',
    blurHash: null,
    description: 'Bottle Sample',
    urls: UrlsDm(
      raw: 'https://images.unsplash.com/photo-1602143407151-7111542de6e8?w=600',
      full: 'https://images.unsplash.com/photo-1602143407151-7111542de6e8?w=600',
      regular: 'https://images.unsplash.com/photo-1602143407151-7111542de6e8?w=600',
      small: 'https://images.unsplash.com/photo-1602143407151-7111542de6e8?w=600',
      thumb: 'https://images.unsplash.com/photo-1602143407151-7111542de6e8?w=600',
    ),
    links: CreateSessionLinksDm(self: '', html: '', download: '', downloadLocation: ''),
    currentUserCollections: [],
    user: UserDm(
      id: 'bottle_user',
      username: 'Unsplash',
      name: 'Unsplash',
      firstName: 'Unsplash',
      profileImage: ProfileImageDm(small: '', medium: '', large: ''),
      links: UserLinksDm(self: '', html: '', photos: '', likes: '', portfolio: ''),
      totalCollections: 0,
      totalLikes: 0,
      totalPhotos: 0,
    ),
  );

  static const CreateSessionDm _textOnImagePhoto = CreateSessionDm(
    id: 'sample_text_1',
    slug: 'text-image-1',
    width: 1080,
    height: 720,
    color: '#000000',
    blurHash: null,
    description: 'Large Text on Image Sample',
    urls: UrlsDm(
      raw: 'https://images.unsplash.com/photo-1516962215378-7fa2e137ae93?w=1080',
      full: 'https://images.unsplash.com/photo-1516962215378-7fa2e137ae93?w=1080',
      regular: 'https://images.unsplash.com/photo-1516962215378-7fa2e137ae93?w=1080',
      small: 'https://images.unsplash.com/photo-1516962215378-7fa2e137ae93?w=1080',
      thumb: 'https://images.unsplash.com/photo-1516962215378-7fa2e137ae93?w=1080',
    ),
    links: CreateSessionLinksDm(self: '', html: '', download: '', downloadLocation: ''),
    currentUserCollections: [],
    user: UserDm(
      id: 'text_user',
      username: 'Unsplash',
      name: 'Unsplash',
      firstName: 'Unsplash',
      profileImage: ProfileImageDm(small: '', medium: '', large: ''),
      links: UserLinksDm(self: '', html: '', photos: '', likes: '', portfolio: ''),
      totalCollections: 0,
      totalLikes: 0,
      totalPhotos: 0,
    ),
  );

  static const CreateSessionDm _documentTextPhoto = CreateSessionDm(
    id: 'sample_doc_text_1',
    slug: 'doc-text-1',
    width: 1080,
    height: 720,
    color: '#000000',
    blurHash: null,
    description: 'Big Print Text Document Sample',
    urls: UrlsDm(
      raw: 'https://images.unsplash.com/photo-1589829085413-56de8ae18c73?w=1080',
      full: 'https://images.unsplash.com/photo-1589829085413-56de8ae18c73?w=1080',
      regular: 'https://images.unsplash.com/photo-1589829085413-56de8ae18c73?w=1080',
      small: 'https://images.unsplash.com/photo-1589829085413-56de8ae18c73?w=1080',
      thumb: 'https://images.unsplash.com/photo-1589829085413-56de8ae18c73?w=1080',
    ),
    links: CreateSessionLinksDm(self: '', html: '', download: '', downloadLocation: ''),
    currentUserCollections: [],
    user: UserDm(
      id: 'doc_text_user',
      username: 'Unsplash',
      name: 'Unsplash',
      firstName: 'Unsplash',
      profileImage: ProfileImageDm(small: '', medium: '', large: ''),
      links: UserLinksDm(self: '', html: '', photos: '', likes: '', portfolio: ''),
      totalCollections: 0,
      totalLikes: 0,
      totalPhotos: 0,
    ),
  );

  static const CreateSessionDm _cupWithTextPhoto = CreateSessionDm(
    id: 'sample_cup_text_1',
    slug: 'cup-text-1',
    width: 1080,
    height: 720,
    color: '#000000',
    blurHash: null,
    description: 'Cup Object with Text and Height Sample',
    urls: UrlsDm(
      raw: 'https://images.unsplash.com/photo-1517256064527-09c73fc73e38?w=1080',
      full: 'https://images.unsplash.com/photo-1517256064527-09c73fc73e38?w=1080',
      regular: 'https://images.unsplash.com/photo-1517256064527-09c73fc73e38?w=1080',
      small: 'https://images.unsplash.com/photo-1517256064527-09c73fc73e38?w=1080',
      thumb: 'https://images.unsplash.com/photo-1517256064527-09c73fc73e38?w=1080',
    ),
    links: CreateSessionLinksDm(self: '', html: '', download: '', downloadLocation: ''),
    currentUserCollections: [],
    user: UserDm(
      id: 'cup_text_user',
      username: 'Unsplash',
      name: 'Unsplash',
      firstName: 'Unsplash',
      profileImage: ProfileImageDm(small: '', medium: '', large: ''),
      links: UserLinksDm(self: '', html: '', photos: '', likes: '', portfolio: ''),
      totalCollections: 0,
      totalLikes: 0,
      totalPhotos: 0,
    ),
  );

  static final List<CreateSessionDm> _fallbackPhotos = [
    _cupWithTextPhoto,
    _bottlePhoto,
    _textOnImagePhoto,
    _documentTextPhoto,
    const CreateSessionDm(
      id: 'fallback_1',
      slug: 'car-1',
      width: 1080,
      height: 720,
      color: '#000000',
      blurHash: null,
      description: 'Car Sample',
      urls: UrlsDm(
        raw: 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?w=600',
        full: 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?w=600',
        regular: 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?w=600',
        small: 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?w=600',
        thumb: 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?w=600',
      ),
      links: CreateSessionLinksDm(self: '', html: '', download: '', downloadLocation: ''),
      currentUserCollections: [],
      user: UserDm(
        id: '1',
        username: 'Unsplash',
        name: 'Unsplash',
        firstName: 'Unsplash',
        profileImage: ProfileImageDm(small: '', medium: '', large: ''),
        links: UserLinksDm(self: '', html: '', photos: '', likes: '', portfolio: ''),
        totalCollections: 0,
        totalLikes: 0,
        totalPhotos: 0,
      ),
    ),
    const CreateSessionDm(
      id: 'fallback_2',
      slug: 'dog-1',
      width: 1080,
      height: 720,
      color: '#000000',
      blurHash: null,
      description: 'Dog Sample',
      urls: UrlsDm(
        raw: 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=600',
        full: 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=600',
        regular: 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=600',
        small: 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=600',
        thumb: 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=600',
      ),
      links: CreateSessionLinksDm(self: '', html: '', download: '', downloadLocation: ''),
      currentUserCollections: [],
      user: UserDm(
        id: '2',
        username: 'Unsplash',
        name: 'Unsplash',
        firstName: 'Unsplash',
        profileImage: ProfileImageDm(small: '', medium: '', large: ''),
        links: UserLinksDm(self: '', html: '', photos: '', likes: '', portfolio: ''),
        totalCollections: 0,
        totalLikes: 0,
        totalPhotos: 0,
      ),
    ),
    const CreateSessionDm(
      id: 'fallback_3',
      slug: 'cat-1',
      width: 1080,
      height: 720,
      color: '#000000',
      blurHash: null,
      description: 'Cat Sample',
      urls: UrlsDm(
        raw: 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=600',
        full: 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=600',
        regular: 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=600',
        small: 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=600',
        thumb: 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=600',
      ),
      links: CreateSessionLinksDm(self: '', html: '', download: '', downloadLocation: ''),
      currentUserCollections: [],
      user: UserDm(
        id: '3',
        username: 'Unsplash',
        name: 'Unsplash',
        firstName: 'Unsplash',
        profileImage: ProfileImageDm(small: '', medium: '', large: ''),
        links: UserLinksDm(self: '', html: '', photos: '', likes: '', portfolio: ''),
        totalCollections: 0,
        totalLikes: 0,
        totalPhotos: 0,
      ),
    ),
    const CreateSessionDm(
      id: 'fallback_4',
      slug: 'coffee-1',
      width: 1080,
      height: 720,
      color: '#000000',
      blurHash: null,
      description: 'Coffee Sample',
      urls: UrlsDm(
        raw: 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=600',
        full: 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=600',
        regular: 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=600',
        small: 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=600',
        thumb: 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=600',
      ),
      links: CreateSessionLinksDm(self: '', html: '', download: '', downloadLocation: ''),
      currentUserCollections: [],
      user: UserDm(
        id: '4',
        username: 'Unsplash',
        name: 'Unsplash',
        firstName: 'Unsplash',
        profileImage: ProfileImageDm(small: '', medium: '', large: ''),
        links: UserLinksDm(self: '', html: '', photos: '', likes: '', portfolio: ''),
        totalCollections: 0,
        totalLikes: 0,
        totalPhotos: 0,
      ),
    ),
  ];
}
