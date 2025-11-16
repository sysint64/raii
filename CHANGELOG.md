## 0.3.2
* Automatic unregister from holder when `RaiiManagerMixin` get disposed.

## 0.3.1
* Update README.md.

## 0.3.0

* Add `addStatusListenerWithLifecycle` to `Animation<T>`;
* Add `RaiiTimer` - The wrapper class that manages the timer's lifecycle;
* Add `unregisterLifecycle` method to the `RaiiLifecycleAware`;
* Add `withLifecycle` extension to the `Timer` which return `RaiiTimer`;
* Init `alwaysAliveRaiiManager` when created;
* Typo `addObserverWithLifeycle` -> `addObserverWithLifecycle`;
* Remove `material` and `cupertino` packages, now everything in the `flutter`;
* Automatic unregister lifecycles when disposed;
* Support all types that extends `ChangeNotifier`;
* Add `RaiiLifecycleHolderTracker` and `RaiiLifecycleHolderTrackerMixin` for lifecycle objects that track their parent holder;
* `RaiiLifecycleMixin` and `RaiiManagerMixin` now implements `RaiiLifecycleHolderTracker`.

## 0.2.0

* Add `RaiiLifecycleAwareWithContext`;
* `RaiiStateMixin` implements now `RaiiLifecycleAwareWithContext`.

## 0.1.0

* Initial release.
