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
// Simple enemy info component to store type-specific values like speed and type
struct EnemyInfo {
  _entity : @system.Entity
  speed : Double
  enemy_type : EnemyType
}

///|
let enemy_infos : Ref[Map[@system.Entity, EnemyInfo]] = { val: Map::new() }

///|
fn set_enemy_info(
  entity : @system.Entity,
  speed : Double,
  enemy_type : EnemyType,
) -> Unit {
  enemy_infos.val.set(entity, { _entity: entity, speed, enemy_type })
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
pub let player_ref : Ref[ @system.Entity?] = { val: None }


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
    } else {
      enemy_infos.val.remove(enemy)
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
  // set enemy info for chaser
  set_enemy_info(enemy, ENEMY_SPEED, EnemyType::Chaser)

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
  set_enemy_info(enemy, ENEMY_SHOOTER_SPEED, EnemyType::Shooter)

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
  set_enemy_info(enemy, ENEMY_KAMIKAZE_SPEED, EnemyType::Kamikaze)

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
