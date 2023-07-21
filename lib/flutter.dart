import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raii/raii.dart';

abstract class LifecycleAwareWithContext extends LifecycleAware {
  BuildContext get context;
}

extension StreamSubscriptionLifecycleRaiiExt<T> on StreamSubscription<T> {
  StreamSubscription<T> withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    StreamSubscriptionLifecycle.attach(
      lifecycleAware,
      sub: this,
      tag: tag,
    );

    return this;
  }
}

extension ScrollControllerRaiiExt on ScrollController {
  ScrollController withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: () => dispose(),
      tag: tag,
    );

    return this;
  }
}

extension AnimationControllerRaiiExt on AnimationController {
  AnimationController withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension TickerRaiiExt on Ticker {
  Ticker withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: () {
        stop();
        dispose();
      },
      tag: tag,
    );

    return this;
  }
}

extension ValueNotifierRaiiExt<T> on ValueNotifier<T> {
  ValueNotifier<T> withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension RenderEditablePainterRaiiExt on RenderEditablePainter {
  RenderEditablePainter withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension MouseTrackerRaiiExt on MouseTracker {
  MouseTracker withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension ViewportOffsetRaiiExt on ViewportOffset {
  ViewportOffset withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension SemanticsOwnerRaiiExt on SemanticsOwner {
  SemanticsOwner withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension RestorationManagerRaiiExt on RestorationManager {
  RestorationManager withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension KeepAliveHandleRaiiExt on KeepAliveHandle {
  KeepAliveHandle withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension DraggableScrollableControllerRaiiExt
    on DraggableScrollableController {
  DraggableScrollableController withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension TextEditingControllerRaiiExt on TextEditingController {
  TextEditingController withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension FocusNodeRaiiExt on FocusNode {
  FocusNode withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension FocusScopeNodeRaiiExt on FocusScopeNode {
  FocusScopeNode withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension FocusManagerRaiiExt on FocusManager {
  FocusManager withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension TransformationControllerRaiiExt on TransformationController {
  TransformationController withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension FixedExtentScrollControllerRaiiExt on FixedExtentScrollController {
  FixedExtentScrollController withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension RestorableRouteFutureRaiiExt<T> on RestorableRouteFuture<T> {
  RestorableRouteFuture<T> withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension SliverOverlapAbsorberHandleRaiiExt on SliverOverlapAbsorberHandle {
  SliverOverlapAbsorberHandle withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension PageControllerRaiiExt on PageController {
  PageController withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension RestorablePropertyRaiiExt<T> on RestorableProperty<T> {
  RestorableProperty<T> withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension RestorableValueRaiiExt<T> on RestorableValue<T> {
  RestorableValue<T> withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension RestorableNumRaiiExt<T extends num> on RestorableNum<T> {
  RestorableNum<T> withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension RestorableDoubleExt on RestorableDouble {
  RestorableDouble withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension RestorableIntExt on RestorableInt {
  RestorableInt withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension RestorableStringExt on RestorableString {
  RestorableString withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension RestorableBoolExt on RestorableBool {
  RestorableBool withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension RestorableBoolNExt on RestorableBoolN {
  RestorableBoolN withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension RestorableNumNExt on RestorableNumN {
  RestorableNumN withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension RestorableDoubleNExt on RestorableDoubleN {
  RestorableDoubleN withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension RestorableIntNExt on RestorableIntN {
  RestorableIntN withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension RestorableStringNExt on RestorableStringN {
  RestorableStringN withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension RestorableDateTimeExt on RestorableDateTime {
  RestorableDateTime withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension RestorableDateTimeNExt on RestorableDateTimeN {
  RestorableDateTimeN withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension RestorableListenableRaiiExt<T extends Listenable>
    on RestorableListenable<T> {
  RestorableListenable<T> withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension RestorableChangeNotifierRaiiExt<T extends ChangeNotifier>
    on RestorableChangeNotifier<T> {
  RestorableChangeNotifier<T> withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension RestorableTextEditingControllerExt
    on RestorableTextEditingController {
  RestorableTextEditingController withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension RestorableEnumNRaiiExt<T extends Enum> on RestorableEnumN<T> {
  RestorableEnumN<T> withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension RestorableEnumRaiiExt<T extends Enum> on RestorableEnum<T> {
  RestorableEnum<T> withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension PlatformRouteInformationProviderExt
    on PlatformRouteInformationProvider {
  PlatformRouteInformationProvider withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension TrackingScrollControllerExt on TrackingScrollController {
  TrackingScrollController withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension ScrollPositionExt on ScrollPosition {
  ScrollPosition withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension ScrollPositionWithSingleContextExt
    on ScrollPositionWithSingleContext {
  ScrollPositionWithSingleContext withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension ScrollbarPainterExt on ScrollbarPainter {
  ScrollbarPainter withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension MultiSelectableSelectionContainerDelegateExt
    on MultiSelectableSelectionContainerDelegate {
  MultiSelectableSelectionContainerDelegate withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension ShortcutManagerExt on ShortcutManager {
  ShortcutManager withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension ShortcutRegistryExt on ShortcutRegistry {
  ShortcutRegistry withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension SnapshotControllerExt on SnapshotController {
  SnapshotController withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension SnapshotPainterExt on SnapshotPainter {
  SnapshotPainter withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension ClipboardStatusNotifierExt on ClipboardStatusNotifier {
  ClipboardStatusNotifier withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension UndoHistoryControllerExt on UndoHistoryController {
  UndoHistoryController withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

class StreamSubscriptionLifecycle<T> with LifecycleMixin {
  StreamSubscriptionLifecycle(this.sub, this.tag);

  StreamSubscriptionLifecycle.attach(
    LifecycleAware lifecycleAware, {
    required this.sub,
    this.tag,
  }) {
    lifecycleAware.registerLifecycle(this);
  }

  final StreamSubscription<T> sub;
  final String? tag;

  @override
  void disposeLifecycle() {
    if (tag != null) {
      debugPrint('[RAII] Dispose lifecycle: $tag');
    }
    sub.cancel();

    super.disposeLifecycle();
  }

  @override
  void initLifecycle() {
    super.initLifecycle();

    if (tag != null) {
      debugPrint('[RAII] Init lifecycle: $tag');
    }
  }
}

class DisposeableLifecycle with LifecycleMixin {
  DisposeableLifecycle.attach(
    LifecycleAware lifecycleAware, {
    required this.dispose,
    this.tag,
  }) {
    lifecycleAware.registerLifecycle(this);
  }

  final VoidCallback dispose;
  final String? tag;

  @override
  void initLifecycle() {
    super.initLifecycle();

    if (tag != null) {
      debugPrint('[RAII] Init lifecycle: $tag');
    }
  }

  @override
  void disposeLifecycle() {
    if (tag != null) {
      debugPrint('[RAII] Dispose lifecycle: $tag');
    }
    dispose();
    super.disposeLifecycle();
  }
}

class ListenableListenerLifecycle<T extends Listenable> with LifecycleMixin {
  ListenableListenerLifecycle.attach(
    LifecycleAware lifecycleAware, {
    required this.listenable,
    required this.onListen,
    this.tag,
  }) {
    lifecycleAware.registerLifecycle(this);
  }

  final T listenable;
  final String? tag;
  final VoidCallback onListen;

  @override
  void initLifecycle() {
    super.initLifecycle();
    if (tag != null) {
      debugPrint('[RAII] Init lifecycle: $tag');
    }
    listenable.addListener(onListen);
  }

  @override
  void disposeLifecycle() {
    if (tag != null) {
      debugPrint('[RAII] Dispose lifecycle: $tag');
    }
    listenable.removeListener(onListen);
    super.disposeLifecycle();
  }
}

class WidgetsBindingObserverLifecycle with LifecycleMixin {
  WidgetsBindingObserverLifecycle.attach(
    LifecycleAware lifecycleAware,
    this.observer, {
    this.tag,
  }) {
    lifecycleAware.registerLifecycle(this);
  }

  final WidgetsBindingObserver observer;
  final String? tag;

  @override
  void initLifecycle() {
    super.initLifecycle();
    if (tag != null) {
      debugPrint('[RAII] Init lifecycle: $tag');
    }
    WidgetsBinding.instance.addObserver(observer);
  }

  @override
  void disposeLifecycle() {
    if (tag != null) {
      debugPrint('[RAII] Dispose lifecycle: $tag');
    }
    WidgetsBinding.instance.removeObserver(observer);
    super.disposeLifecycle();
  }
}

mixin LifecycleAwareWidgetStateMixin<T extends StatefulWidget> on State<T>
    implements LifecycleAwareWithContext {
  final _registeredLifecycles = <Lifecycle>[];
  final _initedServices = <Lifecycle>[];

  bool _attached = false;
  bool _isLifecycleMounted = false;

  @override
  bool isLifecycleMounted() => _isLifecycleMounted;

  @override
  void initLifecycle() {
    _isLifecycleMounted = true;
  }

  @override
  void disposeLifecycle() {
    _isLifecycleMounted = false;
  }

  @override
  void didChangeDependencies() {
    for (final service in _registeredLifecycles) {
      if (!_initedServices.contains(service)) {
        service.initLifecycle();
        _initedServices.add(service);
      }
    }

    if (!_attached) {
      _attached = true;
      initLifecycle();
      onLifecycleAttach();
    }

    super.didChangeDependencies();
  }

  void onLifecycleAttach() {}

  @override
  void dispose() {
    for (final lifecycle in _registeredLifecycles) {
      lifecycle.disposeLifecycle();
    }
    disposeLifecycle();
    super.dispose();
  }

  @override
  void registerLifecycle(Lifecycle lifecycle) {
    if (mounted && !_initedServices.contains(lifecycle)) {
      _registeredLifecycles.add(lifecycle);
      lifecycle.initLifecycle();
      _initedServices.add(lifecycle);
    }

    if (!mounted) {
      lifecycle.disposeLifecycle();
    }
  }
}
