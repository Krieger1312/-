# Проект: Co-op Ecosystem (Godot 4)

Кооперативная игра про машины на Godot 4 (GDScript 2.0, статическая типизация).
Ветка разработки: `claude/godot-coop-multiplayer-arch-05o4wm`.

## Архитектура

- `Core/` — автозагружаемые синглтоны: `EventBus.gd` (шина сигналов),
  `TimeServer.gd` (серверные часы, тикает только у `is_multiplayer_authority()`),
  `SaveManager.gd` (JSON save/load в `user://`).
- `Network/NetworkManager.gd` — автозагрузка. ENet host/join, серверный
  авторитет, регистрация игрока через RPC + рассылка полного ростера новому
  клиенту (паттерн взят из `devmoreir4/godot-3d-multiplayer-template`,
  адаптирован — донор был завязан на инвентарь/бои чужой RPG, это убрано).
- `Player/PlayerController.gd` + `Player.tscn` — `CharacterBody3D`, авторитет
  по имени узла (`set_multiplayer_authority(str(name).to_int())`), камера
  включена только у владельца, `MultiplayerSynchronizer` шлёт position/rotation.
- `Vehicles/VehicleController.gd` + `Vehicle.tscn` — `VehicleBody3D` + 4×
  `VehicleWheel3D`, параметры подвески взяты из `32kda/vehicle_sample`
  (`RedCar.tscn`). Физику симулирует только авторитетный пир, остальные
  `freeze = true` и следуют за синком.
- `Components/InteractableComponent.gd` — базовый компонент взаимодействия
  (сигналы `on_interact`/`on_focus`/`on_unfocus` + EventBus).
- `Components/PhysicalGrabComponent.gd` — хват `RigidBody3D` через
  `PinJoint3D` (не репарентинг — объект не теряет массу/коллизию). Захват/
  отпускание реплицируются через `@rpc("authority", "call_local")`
  (`request_grab`/`request_drop`), авторитет компонента наследуется от
  родителя в `_enter_tree()`.
- `Entities/Props/` — тестовые `RigidBody3D`-префабы для проверки хвата:
  `EnergyDrinkCan.tscn` (Flash Up), `CherryCiderBottle.tscn`,
  `ProcessorBox.tscn` (Ryzen). У всех `continuous_cd = true` — защита от
  проваливания в геометрию при быстрой передаче через сустав.
- `Entities/PropsTestArena.tscn` — тестовая площадка: пол + три префаба выше
  него для ручной проверки физики/хвата.
- `UI/`, `Data/` — пока пустые (зарезервированы под интерфейс и сейвы).

## Известные ограничения / TODO

- **Ни одна .tscn/.gd не проверена реальным движком.** В этом облачном
  окружении нет бинарника Godot, а скачать headless-сборку с
  `github.com/godotengine/godot/releases` нельзя — egress-политика сессии
  блокирует произвольные GitHub-репозитории (разрешены только
  `krieger1312/ecosystem` и `krieger1312/-`), запрос отдаёт 403 через прокси.
  `apt` даёт только Godot 3, который не годится для проверки синтаксиса
  Godot 4 (`@export`, `@rpc`, typed for-loops и т.д. не распознаются).
  Чтобы включить проверку `./godot --headless --check-only <script>.gd`,
  нужно расширить сетевую политику окружения (см. `code.claude.com/docs/en/claude-code-on-the-web`,
  раздел Environment settings) и открыть новую сессию — на лету политика не
  обновляется.
- Открыть проект в Godot 4.3+ вручную перед первым запуском и проверить, что
  все `.tscn` парсятся (особенно рукописные — `Player.tscn`, `Vehicle.tscn`,
  три префаба в `Entities/Props/`, `PropsTestArena.tscn`).
- `PhysicalGrabComponent` не проверялся живьём на проваливание объектов при
  передаче между игроками — только теоретическая защита через `continuous_cd`.
- Input map в `project.godot`: `move_forward/backward/left/right`, `jump`,
  `sprint`, `brake`, `interact` — заданы дефолтные клавиши (WASD/Space/Shift/E),
  не проверялись в редакторе.
- Игровой логики (геймплей, UI, сохранения) ещё нет — заложен только каркас.
