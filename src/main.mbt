///|
const ZOOM : Double = 1.0

///|
const VIEWPORT_WIDTH : Double = 640.0

///|
const VIEWPORT_HEIGHT : Double = 360.0

///|
const REAL_VIEWPORT_WIDTH : Double = VIEWPORT_WIDTH * ZOOM

///|
const REAL_VIEWPORT_HEIGHT : Double = VIEWPORT_HEIGHT * ZOOM

///|
const MOVE_SPEED : Double = 150.0

///|
const BULLET_SPEED : Double = 400.0

///|
const BULLET_LIFETIME : Double = 3.0

///|
const ENEMY_SPEED : Double = 100.0

///|
const ENEMY_SHOOTER_SPEED : Double = 80.0

///|
const ENEMY_KAMIKAZE_SPEED : Double = 150.0

///|
// Enemy types
enum EnemyType {
  Chaser
  Shooter
  Kamikaze
}

///|
// Game state
struct GameState {
  mut score : Int
  mut wave : Int
  mut wave_enemies_remaining : Int
  mut wave_enemies_spawned : Int
  mut wave_spawn_timer : Double
  mut wave_complete : Bool
  mut shop_open : Bool
  mut upgrade_points : Int
  mut player_entity : @system.Entity?
  mut enemies : Array[@system.Entity]
  mut bullets : Array[@system.Entity]
  mut enemy_bullets : Array[@system.Entity]
  mut lights : Array[@system.Entity]

  // Player stats
  mut player_health : Int
  player_max_health : Int
  player_damage_multiplier : Double
  player_speed_multiplier : Double
  mut player_invuln_timer : Double
}

///|
pub let game_state : GameState = {
  score: 0,
  wave: 1,
  wave_enemies_remaining: 0,
  wave_enemies_spawned: 0,
  wave_spawn_timer: 0.0,
  wave_complete: false,
  shop_open: false,
  upgrade_points: 0,
  player_entity: None,
  enemies: [],
  bullets: [],
  enemy_bullets: [],
  lights: [],

  // Player stats
  player_health: 3,
  player_max_health: 3,
  player_damage_multiplier: 1.0,
  player_speed_multiplier: 1.0,
  player_invuln_timer: 0.0,
}

///|
// Simple enemy info component to store type-specific values like speed
struct EnemyInfo {
  _entity : @system.Entity
  speed : Double
}

///|
let enemy_infos : Ref[Array[EnemyInfo]] = { val: [] }

///|
pub fn set_enemy_info(entity : @system.Entity, speed : Double) -> Unit {
  enemy_infos.val.push({ _entity: entity, speed })
}

///|
fn find_enemy_info(entity : @system.Entity) -> Int {
  let mut i = 0
  while i < enemy_infos.val.length() {
    if enemy_infos.val[i]._entity == entity {
      return i
    }
    i = i + 1
  }
  -1
}

///|
// Small accessors so other packages (for example Scenes) can read game state
// without accessing package-level mutable vars directly.
pub fn get_player_health() -> Int {
  game_state.player_health
}

///|
pub fn get_wave_enemies_spawned() -> Int {
  game_state.wave_enemies_spawned
}

///|
pub fn get_upgrade_points() -> Int {
  game_state.upgrade_points
}

///|
pub fn get_player_max_health() -> Int {
  game_state.player_max_health
}

///|
pub fn get_player_damage_multiplier() -> Double {
  game_state.player_damage_multiplier
}

///|
pub fn get_score() -> Int {
  game_state.score
}

// Scenes functions are called via the package qualifier (see src/moon.pkg.json)

///|
// Collision layers
pub let player_collision_layer : @collision.CollisionLayer = @collision.CollisionLayer::new()

///|
pub let enemy_collision_layer : @collision.CollisionLayer = @collision.CollisionLayer::new()

///|
pub let bullet_collision_layer : @collision.CollisionLayer = @collision.CollisionLayer::new()

///|
pub let light_collision_layer : @collision.CollisionLayer = @collision.CollisionLayer::new()

///|
pub let enemy_bullet_collision_layer : @collision.CollisionLayer = @collision.CollisionLayer::new()

///|
let player_ref : Ref[@system.Entity?] = { val: None }

///|
fn main {
  @system.App::new()
  .with_canvas_width(REAL_VIEWPORT_WIDTH)
  .with_canvas_height(REAL_VIEWPORT_HEIGHT)
  .with_image_smooth(false)
  .with_zoom(ZOOM)
  .with_fps(60)
  .add_plugin(@plugins.default_plugin)
  .add_system(game_start, schedule=Startup)
  .add_system(tick, schedule=Update)
  .add_system(wave_management_system, schedule=Update)
  .add_system(player_move_system, schedule=Update)
  .add_system(shooting_system, schedule=Update)
  .add_system(enemy_ai_system, schedule=Update)
  .add_system(enemy_shooting_system, schedule=Update)
  .add_system(enemy_spawn_system, schedule=Update)
  .add_system(update_health_system, schedule=Update)
  .add_system(input_system, schedule=Update)
  .add_system(@collision.area_collide_system, schedule=Update)
  .run()
}

///|
fn game_start(_delta : Double) -> Unit {
  let p = spawn_player(
    @math.Vec2D(REAL_VIEWPORT_WIDTH / 2.0, REAL_VIEWPORT_HEIGHT / 2.0),
  )
  player_ref.val = Some(p)
  game_state.player_entity = Some(p)

  // Ensure global player health matches max at start
  game_state.player_health = game_state.player_max_health
  println(
    "game_start: player spawned, health=" + game_state.player_health.to_string(),
  )
  // Give player a short invulnerability window to avoid instant death on spawn
  set_invulnerability(p, 1.0)
  println("game_start: player invulnerable for 1.0s")

  // Initialize first wave after a short delay so the player has time to be invulnerable
  // Increased to 1.0s to give a safer startup window
  @system.timeout(1.0, true, fn() { start_wave() })
  // Initialize UI layer
  @Scenes.init_scene_ui(0.0)
}

///|
fn tick(_delta : Double) -> Unit {
  // Update game logic, clean up dead entities, etc.
  cleanup_dead_entities()

  // Update player invulnerability timer
  if game_state.player_invuln_timer > 0.0 {
    game_state.player_invuln_timer = game_state.player_invuln_timer - _delta
    if game_state.player_invuln_timer < 0.0 {
      game_state.player_invuln_timer = 0.0
    }
  }

  // Debug: Print score when it changes
  if game_state.score > 0 {
    // This helps us verify the light collection is working
    ignore("Current Score: " + game_state.score.to_string())
  }

  // Update HUD each frame. delta can be 0 in some contexts, guard division.
  let fps = if _delta > 0.0 { (1.0 / _delta).to_int() } else { 0 }
  // Refresh UI layer with current values
  @Scenes.update_hud(game_state.player_health, game_state.score, fps)
}

///|
fn cleanup_dead_entities() -> Unit {
  // Clean up bullets
  let alive_bullets = []
  for bullet in game_state.bullets {
    if bullet.is_alive() {
      alive_bullets.push(bullet)
    }
  }
  game_state.bullets = alive_bullets

  // Clean up enemies
  let alive_enemies = []
  for enemy in game_state.enemies {
    if enemy.is_alive() {
      alive_enemies.push(enemy)
    }
  }
  game_state.enemies = alive_enemies

  // Clean up lights
  let alive_lights = []
  for light in game_state.lights {
    if light.is_alive() {
      alive_lights.push(light)
    }
  }
  game_state.lights = alive_lights

  // Clean up enemy bullets
  let alive_enemy_bullets = []
  for bullet in game_state.enemy_bullets {
    if bullet.is_alive() {
      alive_enemy_bullets.push(bullet)
    }
  }
  game_state.enemy_bullets = alive_enemy_bullets
}

///|
fn clamp(value : Double, min : Double, max : Double) -> Double {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}

///|
let random_seed : Ref[Int] = { val: 12345 }

///|
fn random() -> Double {
  // Simple linear congruential generator
  random_seed.val = (random_seed.val * 1103515 + 12345) % 1048576
  random_seed.val.to_double() / 1048576.0
}

///|
fn start_wave() -> Unit {
  game_state.wave_enemies_remaining = 3 + game_state.wave * 2
  game_state.wave_enemies_spawned = 0
  game_state.wave_spawn_timer = 0.0
  game_state.wave_complete = false
}

///|
fn wave_management_system(_delta : Double) -> Unit {
  // Check if wave is complete
  if game_state.wave_enemies_remaining <= 0 && game_state.enemies.length() == 0 {
    if not(game_state.wave_complete) {
      game_state.wave_complete = true
      game_state.wave += 1
      game_state.upgrade_points += game_state.wave / 2

      // Start next wave after a delay
      @system.timeout(2.0, true, fn() { start_wave() })
    }
  }
}

///|
fn input_system(_delta : Double) -> Unit {
  // Toggle shop with T key (Tab not available)
  if @inputs.is_just_pressed(@inputs.KeyT) {
    println("T pressed - toggling shop")
    game_state.shop_open = not(game_state.shop_open)
  }
}

///|
fn enemy_shooting_system(_delta : Double) -> Unit {
  // Shooter enemies fire bullets at player
  guard game_state.player_entity is Some(player) else { return }
  guard player.is_alive() else { return }
  guard @position.positions.get(player) is Some(player_pos) else { return }
  // Don't let enemies shoot while the player is invulnerable at startup
  if game_state.player_invuln_timer > 0.0 {
    return
  }
  for enemy in game_state.enemies {
    if enemy.is_alive() {
      // Check if this is a shooter enemy (we'll store type in a component later)
      if random() < 0.005 { // 0.5% chance per frame to shoot
        guard @position.positions.get(enemy) is Some(enemy_pos) else {
          continue
        }
        let direction = player_pos.0 - enemy_pos.0
        if direction != @math.Vec2D::zero() {
          let enemy_bullet = spawn_enemy_bullet(enemy_pos.0, direction)
          game_state.enemy_bullets.push(enemy_bullet)
        }
      }
    }
  }
}

///|
fn player_move_system(delta : Double) -> Unit {
  guard player_ref.val is Some(e) else { return }
  guard @position.positions.get(e) is Some(pos) else { return }
  let dir = @inputs.key_vector(
    @inputs.KeyW,
    @inputs.KeyS,
    @inputs.KeyA,
    @inputs.KeyD,
  )
  if dir != @math.Vec2D::zero() {
    let speed = MOVE_SPEED * game_state.player_speed_multiplier
    let new_pos = pos.0 + dir.normalize().scalar_mul(speed * delta)
    // Keep player within bounds
    let bounded_x = clamp(new_pos[X], 16.0, REAL_VIEWPORT_WIDTH - 16.0)
    let bounded_y = clamp(new_pos[Y], 16.0, REAL_VIEWPORT_HEIGHT - 16.0)
    @position.positions.set(e, @math.Vec2D(bounded_x, bounded_y))
  }
}

///|
fn shooting_system(_delta : Double) -> Unit {
  guard game_state.player_entity is Some(player) else { return }
  guard player.is_alive() else { return }
  guard @position.positions.get(player) is Some(player_pos) else { return }

  // Check for mouse click to shoot
  if @inputs.is_mouse_just_pressed(@inputs.MouseButton::Left) {
    let mouse_pos = @inputs.mouse.pos
    let direction = mouse_pos - player_pos.0

    // Check if direction is non-zero
    if direction != @math.Vec2D::zero() {
      let bullet = spawn_bullet(player_pos.0, direction)
      game_state.bullets.push(bullet)
    }
  }
}

///|
fn enemy_ai_system(_delta : Double) -> Unit {
  guard game_state.player_entity is Some(player) else { return }
  guard player.is_alive() else { return }
  guard @position.positions.get(player) is Some(player_pos) else { return }
  for enemy in game_state.enemies {
    if enemy.is_alive() {
      guard @position.positions.get(enemy) is Some(enemy_pos) else { continue }

      // Calculate direction to player
      let direction = player_pos.0 - enemy_pos.0
      if direction != @math.Vec2D::zero() {
        // Determine enemy type based on sprite and use appropriate speed
        guard @sprite.sprites.get(enemy) is Some(_sprite) else { continue }

        // Get the speed based on enemy_info if present
        let info_idx = find_enemy_info(enemy)
        let speed = if info_idx >= 0 {
          enemy_infos.val[info_idx].speed
        } else {
          ENEMY_SPEED
        }
        let velocity = direction.normalize().scalar_mul(speed)
        @velocity.velocities.set(enemy, velocity)
      }
    }
  }
}

///|
fn enemy_spawn_system(delta : Double) -> Unit {
  // If player is invulnerable at startup, delay spawning entirely
  if game_state.player_invuln_timer > 0.0 {
    return
  }
  // Only spawn enemies during active wave and if we haven't spawned all enemies
  if game_state.wave_enemies_remaining <= 0 || game_state.wave_complete {
    return
  }
  game_state.wave_spawn_timer += delta

  // Spawn enemies based on wave timing
  let spawn_interval = 2.0 - game_state.wave.to_double() * 0.1 // Faster spawning in higher waves
  let min_spawn_interval = 0.5
  let actual_spawn_interval = if spawn_interval < min_spawn_interval {
    min_spawn_interval
  } else {
    spawn_interval
  }
  if game_state.wave_spawn_timer >= actual_spawn_interval {
    game_state.wave_spawn_timer = 0.0
    let side = (random() * 4.0).to_int()
    let mut spawn_pos = match side {
      0 => @math.Vec2D(-20.0, random() * REAL_VIEWPORT_HEIGHT) // Left edge
      1 =>
        @math.Vec2D(REAL_VIEWPORT_WIDTH + 20.0, random() * REAL_VIEWPORT_HEIGHT) // Right edge
      2 => @math.Vec2D(random() * REAL_VIEWPORT_WIDTH, -20.0) // Top edge
      _ =>
        @math.Vec2D(random() * REAL_VIEWPORT_WIDTH, REAL_VIEWPORT_HEIGHT + 20.0) // Bottom edge
    }

    // Prevent spawning enemies too close to the player (avoid instant collisions)
    let safe_spawn_distance : Double = 80.0
    guard game_state.player_entity is Some(player) else { () }
    if @position.positions.get(player) is Some(player_pos) {
      // If spawn_pos is within SAFE_SPAWN_DISTANCE of player, move it outwards
      let to_player = spawn_pos - player_pos.0
      let dx = to_player[X]
      let dy = to_player[Y]
      let dist_sq = dx * dx + dy * dy
      let min_sq = safe_spawn_distance * safe_spawn_distance
      if dist_sq < min_sq {
        // If direction is zero (unlikely), nudge to left of player
        let new_pos = if to_player == @math.Vec2D::zero() {
          @math.Vec2D(player_pos.0[X] - safe_spawn_distance, player_pos.0[Y])
        } else {
          player_pos.0 + to_player.normalize().scalar_mul(safe_spawn_distance)
        }
        spawn_pos = new_pos
      }
    }

    // Choose enemy type based on wave
    let enemy_type = choose_enemy_type()
    let enemy = spawn_enemy_of_type(spawn_pos, enemy_type)
    game_state.enemies.push(enemy)
    game_state.wave_enemies_spawned += 1
    game_state.wave_enemies_remaining -= 1
  }
}

///|
fn choose_enemy_type() -> EnemyType {
  // Simple enemy type selection based on wave
  let wave = game_state.wave
  if wave <= 2 {
    EnemyType::Chaser
  } else if wave <= 5 {
    if random() < 0.7 {
      EnemyType::Chaser
    } else {
      EnemyType::Shooter
    }
  } else {
    let rand = random()
    if rand < 0.5 {
      EnemyType::Chaser
    } else if rand < 0.8 {
      EnemyType::Shooter
    } else {
      EnemyType::Kamikaze
    }
  }
}

///|
fn spawn_enemy_of_type(
  position : @math.Vec2D,
  enemy_type : EnemyType,
) -> @system.Entity {
  match enemy_type {
    EnemyType::Chaser => spawn_enemy(position)
    EnemyType::Shooter => spawn_shooter_enemy(position)
    EnemyType::Kamikaze => spawn_kamikaze_enemy(position)
  }
}

///|
fn spawn_enemy_bullet(
  position : @math.Vec2D,
  direction : @math.Vec2D,
) -> @system.Entity {
  let bullet = @system.Entity::new()

  // Set position and velocity
  @position.positions.set(bullet, position)
  let velocity = direction.normalize().scalar_mul(BULLET_SPEED * 0.7) // Slower than player bullets
  @velocity.velocities.set(bullet, velocity)

  // Set up sprite (use enemy bullet sprite)
  let tile_size : Double = 8.0
  let tile_offset : @math.Vec2D = @math.Vec2D(8.0, 8.0) // Different sprite for enemy bullets
  let sprite = @sprite.Sprite::from_animation(
    @sprite.Animation::new(
      @sprite.frames_from_atlas(
        "assets/textures/entities.png",
        1,
        width=tile_size,
        height=tile_size,
        offset=tile_offset,
      ),
      loop_=false,
      fps=0.0,
      // upscale to 24x24 (smaller than player bullets)
      transform=@math.Transform::from_scale(3.0, 3.0),
    ),
    3, // Z-index
    // center the sprite on its position
    offset=@math.Vec2D(-tile_size * 1.5, -tile_size * 1.5),
  )
  @sprite.sprites.set(bullet, sprite)

  // Set up collision
  @collision.collision_layers.set(bullet, enemy_bullet_collision_layer)
  @collision.shapes.set(
    bullet,
    @collision.CollisionShape::Rect(
      size=@math.Vec2D(tile_size * 3.0, tile_size * 3.0),
      offset=@math.Vec2D(-tile_size * 1.5, -tile_size * 1.5),
    ),
  )

  // Set up area to detect player hits
  let hit_area = @collision.Area::new(
    @collision.CollisionMask::new([player_collision_layer]),
  )
  hit_area.on_enter(fn(target_entity) {
    if @collision.collision_layers.get(target_entity) ==
      Some(player_collision_layer) {
      // Enemy bullet hit player - destroy bullet and damage player
      bullet.destroy()
      // use Health component API to apply damage; source position is bullet position
      guard @position.positions.get(bullet) is Some(bpos) else { return }
      // respect global player invulnerability as an extra guard
      guard game_state.player_entity is Some(pe) else { return }
      if pe == target_entity && game_state.player_invuln_timer > 0.0 {
        // skip damage while player is invulnerable
        return
      }
      take_damage(target_entity, 1, Some(bpos.0))
    }
  })
  @collision.areas.set(bullet, hit_area)

  // Auto-destroy after lifetime
  @system.timeout(BULLET_LIFETIME, true, fn() { bullet.destroy() })
  bullet
}

///|
fn spawn_bullet(
  position : @math.Vec2D,
  direction : @math.Vec2D,
) -> @system.Entity {
  let bullet = @system.Entity::new()

  // Set position and velocity
  @position.positions.set(bullet, position)
  let velocity = direction.normalize().scalar_mul(BULLET_SPEED)
  @velocity.velocities.set(bullet, velocity)

  // Set up sprite (use bullet sprite from entities texture)
  let tile_size : Double = 8.0
  let tile_offset : @math.Vec2D = @math.Vec2D(0.0, 8.0) // bullet sprite position
  let sprite = @sprite.Sprite::from_animation(
    @sprite.Animation::new(
      @sprite.frames_from_atlas(
        "assets/textures/entities.png",
        1,
        width=tile_size,
        height=tile_size,
        offset=tile_offset,
      ),
      loop_=false,
      fps=0.0,
      // upscale to 32x32
      transform=@math.Transform::from_scale(4.0, 4.0),
    ),
    3, // Z-index
    // center the sprite on its position
    offset=@math.Vec2D(-tile_size * 2.0, -tile_size * 2.0),
  )
  @sprite.sprites.set(bullet, sprite)

  // Set up collision
  @collision.collision_layers.set(bullet, bullet_collision_layer)
  @collision.shapes.set(
    bullet,
    @collision.CollisionShape::Rect(
      size=@math.Vec2D(tile_size * 4.0, tile_size * 4.0),
      offset=@math.Vec2D(-tile_size * 2.0, -tile_size * 2.0),
    ),
  )

  // Set up area to detect enemy hits
  let hit_area = @collision.Area::new(
    @collision.CollisionMask::new([enemy_collision_layer]),
  )
  hit_area.on_enter(fn(target_entity) {
    if @collision.collision_layers.get(target_entity) ==
      Some(enemy_collision_layer) {
      // Bullet hit enemy - destroy bullet and apply damage via Health
      bullet.destroy()
      guard @position.positions.get(bullet) is Some(bpos) else { return }
      take_damage(target_entity, 1, Some(bpos.0))
    }
  })
  @collision.areas.set(bullet, hit_area)

  // Auto-destroy after lifetime
  @system.timeout(BULLET_LIFETIME, true, fn() { bullet.destroy() })
  bullet
}

///|
fn spawn_enemy(position : @math.Vec2D) -> @system.Entity {
  let enemy = @system.Entity::new()

  // Set position and velocity
  @position.positions.set(enemy, position)
  @velocity.velocities.set(enemy, @math.Vec2D(0.0, 0.0))

  // Set up sprite (use red enemy from entities texture)
  let tile_size : Double = 8.0
  let tile_offset : @math.Vec2D = @math.Vec2D(0.0, 0.0) // red enemy sprite position
  let sprite = @sprite.Sprite::from_animation(
    @sprite.Animation::new(
      @sprite.frames_from_atlas(
        "assets/textures/entities.png",
        1,
        width=tile_size,
        height=tile_size,
        offset=tile_offset,
      ),
      loop_=false,
      fps=0.0,
      // upscale to 48x48
      transform=@math.Transform::from_scale(6.0, 6.0),
    ),
    2, // Z-index
    // center the sprite on its position
    offset=@math.Vec2D(-tile_size * 3.0, -tile_size * 3.0),
  )
  @sprite.sprites.set(enemy, sprite)
  // add health component for basic enemy
  add_health(enemy, 1)

  // Set up collision
  @collision.collision_layers.set(enemy, enemy_collision_layer)
  @collision.shapes.set(
    enemy,
    @collision.CollisionShape::Rect(
      size=@math.Vec2D(tile_size * 6.0, tile_size * 6.0),
      offset=@math.Vec2D(-tile_size * 3.0, -tile_size * 3.0),
    ),
  )
  enemy
}

///|
fn spawn_light(position : @math.Vec2D) -> @system.Entity {
  let light = @system.Entity::new()

  // Set position
  @position.positions.set(light, position)
  @velocity.velocities.set(light, @math.Vec2D(0.0, 0.0))

  // Set up sprite (use light/powerup sprite from power-ups texture)
  let tile_size : Double = 8.0
  let tile_offset : @math.Vec2D = @math.Vec2D(16.0, 8.0) // light orb sprite position
  let sprite = @sprite.Sprite::from_animation(
    @sprite.Animation::new(
      @sprite.frames_from_atlas(
        "assets/textures/power-ups.png",
        1,
        width=tile_size,
        height=tile_size,
        offset=tile_offset,
      ),
      loop_=false,
      fps=0.0,
      // upscale to 24x24
      transform=@math.Transform::from_scale(3.0, 3.0),
    ),
    1, // Z-index
    // center the sprite on its position
    offset=@math.Vec2D(-tile_size * 1.5, -tile_size * 1.5),
  )
  @sprite.sprites.set(light, sprite)

  // Set up collision for collection
  @collision.collision_layers.set(light, light_collision_layer)
  @collision.shapes.set(
    light,
    @collision.CollisionShape::Rect(
      size=@math.Vec2D(tile_size * 3.0, tile_size * 3.0),
      offset=@math.Vec2D(-tile_size * 1.5, -tile_size * 1.5),
    ),
  )
  light
}

///|
fn spawn_shooter_enemy(position : @math.Vec2D) -> @system.Entity {
  let enemy = @system.Entity::new()

  // Set position and velocity
  @position.positions.set(enemy, position)
  @velocity.velocities.set(enemy, @math.Vec2D(0.0, 0.0))

  // Set up sprite (use green enemy from entities texture)
  let tile_size : Double = 8.0
  let tile_offset : @math.Vec2D = @math.Vec2D(8.0, 0.0) // green shooter enemy sprite position
  let sprite = @sprite.Sprite::from_animation(
    @sprite.Animation::new(
      @sprite.frames_from_atlas(
        "assets/textures/entities.png",
        1,
        width=tile_size,
        height=tile_size,
        offset=tile_offset,
      ),
      loop_=false,
      fps=0.0,
      // upscale to 48x48
      transform=@math.Transform::from_scale(6.0, 6.0),
    ),
    2, // Z-index
    // center the sprite on its position
    offset=@math.Vec2D(-tile_size * 3.0, -tile_size * 3.0),
  )
  @sprite.sprites.set(enemy, sprite)
  // add health for shooter enemy
  add_health(enemy, 1)
  // set enemy info speed for shooter
  set_enemy_info(enemy, ENEMY_SHOOTER_SPEED)

  // Set up collision
  @collision.collision_layers.set(enemy, enemy_collision_layer)
  @collision.shapes.set(
    enemy,
    @collision.CollisionShape::Rect(
      size=@math.Vec2D(tile_size * 6.0, tile_size * 6.0),
      offset=@math.Vec2D(-tile_size * 3.0, -tile_size * 3.0),
    ),
  )
  enemy
}

///|
fn spawn_kamikaze_enemy(position : @math.Vec2D) -> @system.Entity {
  let enemy = @system.Entity::new()

  // Set position and velocity
  @position.positions.set(enemy, position)
  @velocity.velocities.set(enemy, @math.Vec2D(0.0, 0.0))

  // Set up sprite (use blue kamikaze enemy from entities texture)
  let tile_size : Double = 8.0
  let tile_offset : @math.Vec2D = @math.Vec2D(16.0, 0.0) // blue kamikaze enemy sprite position
  let sprite = @sprite.Sprite::from_animation(
    @sprite.Animation::new(
      @sprite.frames_from_atlas(
        "assets/textures/entities.png",
        1,
        width=tile_size,
        height=tile_size,
        offset=tile_offset,
      ),
      loop_=false,
      fps=0.0,
      // upscale to 48x48
      transform=@math.Transform::from_scale(6.0, 6.0),
    ),
    2, // Z-index
    // center the sprite on its position
    offset=@math.Vec2D(-tile_size * 3.0, -tile_size * 3.0),
  )
  @sprite.sprites.set(enemy, sprite)
  // add health for kamikaze enemy
  add_health(enemy, 1)
  // set enemy info speed for kamikaze
  set_enemy_info(enemy, ENEMY_KAMIKAZE_SPEED)

  // Set up collision
  @collision.collision_layers.set(enemy, enemy_collision_layer)
  @collision.shapes.set(
    enemy,
    @collision.CollisionShape::Rect(
      size=@math.Vec2D(tile_size * 6.0, tile_size * 6.0),
      offset=@math.Vec2D(-tile_size * 3.0, -tile_size * 3.0),
    ),
  )
  enemy
}
