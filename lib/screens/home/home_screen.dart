import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:tensorflow_demo/models/screen_params.dart';
import 'package:tensorflow_demo/services/navigation_service.dart';
import 'package:tensorflow_demo/values/app_routes.dart';
import 'package:tensorflow_demo/values/enumerations.dart';

import 'home_screen_store.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    ScreenParams.screenSize = MediaQuery.sizeOf(context);
    final homeScreenStore = context.read<HomeScreenStore>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          Observer(
            builder: (_) => IconButton(
              icon: const Icon(Icons.photo_library),
              tooltip: 'Pick Image from Gallery',
              onPressed: homeScreenStore.isAnalyzingImage ||
                      homeScreenStore.isPickerActive
                  ? null
                  : homeScreenStore.pickImageFromGallery,
            ),
          ),
        ],
      ),
      floatingActionButton: Observer(
        builder: (_) => FloatingActionButton(
          heroTag: 'live_object_detection',
          onPressed: homeScreenStore.isAnalyzingImage ||
                  homeScreenStore.isPickerActive
              ? null
              : () => NavigationService.instance.pushNamed(
                    AppRoutes.cameraScreen,
                  ),
          child: SvgPicture.asset(
            'assets/vectors/camera.svg',
            width: 28,
            height: 28,
          ),
        ),
      ),
      body: Observer(
        builder: (_) {
          return switch (homeScreenStore.unsplashPhotosState) {
            NetworkState.idle => const SizedBox.shrink(),
            NetworkState.loading => const Center(
                child: RepaintBoundary(child: CircularProgressIndicator()),
              ),
            NetworkState.error => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    const Text('Unable to load network photos.'),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FilledButton(
                          onPressed: homeScreenStore.refresh,
                          child: const Text('Retry'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: homeScreenStore.pickImageFromGallery,
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Pick Image'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            NetworkState.success => Builder(
                builder: (context) {
                  final bottomPadding = MediaQuery.paddingOf(context).bottom + 88;
                  return RefreshIndicator(
                    onRefresh: homeScreenStore.refresh,
                    child: homeScreenStore.photos.isEmpty
                        ? LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: Container(
                                  constraints: BoxConstraints(
                                    minHeight: constraints.maxHeight,
                                  ),
                                  padding: EdgeInsets.only(bottom: bottomPadding),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.photo_outlined,
                                          size: 64,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(height: 12),
                                        const Text('No photos available.'),
                                        const SizedBox(height: 12),
                                        ElevatedButton(
                                          onPressed: homeScreenStore.refresh,
                                          child: const Text('Refresh'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          )
                        : ListView(
                            padding: EdgeInsets.fromLTRB(
                              16,
                              16,
                              16,
                              bottomPadding,
                            ),
                            physics: const AlwaysScrollableScrollPhysics(),
                            controller: homeScreenStore.scrollController,
                            children: [
                              Observer(
                                builder: (_) => GridView.builder(
                                  shrinkWrap: true,
                                  primary: false,
                                  itemCount: homeScreenStore.photos.length,
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    childAspectRatio: 3 / 4,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                  ),
                                  itemBuilder: (_, index) {
                                    final urls =
                                        homeScreenStore.photos[index].urls;
                                    final isItemLoading =
                                        homeScreenStore.isAnalyzingImage &&
                                            homeScreenStore.loadingImageUrl ==
                                                urls.small;

                                    return GestureDetector(
                                      onTap: homeScreenStore.isAnalyzingImage
                                          ? null
                                          : () async => homeScreenStore
                                              .analyzeNetworkImage(
                                              urls.small,
                                            ),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          ClipRRect(
                                            borderRadius:
                                                const BorderRadius.all(
                                              Radius.circular(16),
                                            ),
                                            child: Image.network(
                                              urls.small,
                                              fit: BoxFit.cover,
                                              errorBuilder: (
                                                context,
                                                error,
                                                stackTrace,
                                              ) {
                                                return Container(
                                                  color: Colors.grey[300],
                                                  child: const Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.center,
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .broken_image_outlined,
                                                        color: Colors.grey,
                                                        size: 32,
                                                      ),
                                                      SizedBox(height: 4),
                                                      Text(
                                                        'Image unavailable',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          if (isItemLoading)
                                            Container(
                                              decoration: BoxDecoration(
                                                color: Colors.black45,
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              child: const Center(
                                                child: CircularProgressIndicator(
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              Observer(
                                builder: (_) => Visibility(
                                  visible: homeScreenStore
                                      .paginatedState.isLoading,
                                  child: const Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Center(
                                      child: RepaintBoundary(
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  );
                },
              ),
          };
        },
      ),
    );
  }
}
