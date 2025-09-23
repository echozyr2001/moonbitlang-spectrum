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
// Game state
struct GameState {
  mut score : Int
  mut player_entity : @system.Entity?
  mut enemies : Array[@system.Entity]
  mut bullets : Array[@system.Entity]
  mut lights : Array[@system.Entity]
}

///|
pub let game_state : GameState = {
  score: 0,
  player_entity: None,
  enemies: [],
  bullets: [],
  lights: [],
}

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
  .add_system(player_move_system, schedule=Update)
  .add_system(shooting_system, schedule=Update)
  .add_system(enemy_ai_system, schedule=Update)
  .add_system(enemy_spawn_system, schedule=Update)
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
}

///|
fn tick(_delta : Double) -> Unit {
  // Update game logic, clean up dead entities, etc.
  cleanup_dead_entities()

  // Debug: Print score when it changes
  if game_state.score > 0 {
    // This helps us verify the light collection is working
    ignore("Current Score: " + game_state.score.to_string())
  }
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
    let new_pos = pos.0 + dir.normalize().scalar_mul(MOVE_SPEED * delta)
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
        let velocity = direction.normalize().scalar_mul(ENEMY_SPEED)
        @velocity.velocities.set(enemy, velocity)
      }
    }
  }
}

///|
fn enemy_spawn_system(_delta : Double) -> Unit {
  // Simple spawning: create enemy occasionally
  if random() < 0.008 { // Spawn rate
    let side = (random() * 4.0).to_int()
    let spawn_pos = match side {
      0 => @math.Vec2D(-20.0, random() * REAL_VIEWPORT_HEIGHT) // Left edge
      1 =>
        @math.Vec2D(REAL_VIEWPORT_WIDTH + 20.0, random() * REAL_VIEWPORT_HEIGHT) // Right edge  
      2 => @math.Vec2D(random() * REAL_VIEWPORT_WIDTH, -20.0) // Top edge
      _ =>
        @math.Vec2D(random() * REAL_VIEWPORT_WIDTH, REAL_VIEWPORT_HEIGHT + 20.0) // Bottom edge
    }
    let enemy = spawn_enemy(spawn_pos)
    game_state.enemies.push(enemy)
  }
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
      // Bullet hit enemy - destroy both
      bullet.destroy()
      target_entity.destroy()

      // Create light at enemy position
      guard @position.positions.get(target_entity) is Some(enemy_pos) else {
        return
      }
      let light = spawn_light(enemy_pos.0)
      game_state.lights.push(light)
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
