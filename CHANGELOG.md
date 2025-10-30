## 0.3.0

* Add `addStatusListenerWithLifecycle` to `Animation<T>`;
* Add `RaiiTimer` - The wrapper class that manages the timer's lifecycle;
* Add `unregisterLifecycle` method to the `RaiiLifecycleAware`;
* Add `withLifecycle` extension to the `Timer` which return `RaiiTimer`;
* Init `alwaysAliveRaiiManager` when created;
* Typo `addObserverWithLifeycle` -> `addObserverWithLifecycle`.

## 0.2.0

* Add `RaiiLifecycleAwareWithContext`;
* `RaiiStateMixin` implements now `RaiiLifecycleAwareWithContext`.

## 0.1.0

* Initial release.
