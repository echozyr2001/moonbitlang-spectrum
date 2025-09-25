///|
// Component-like Health system (MoonBit adaptation of the C++ HealthSystem)
// Provides per-entity health storage, take_damage API, and a system
// to process damage events (reset flags, handle death). Also applies a
// brief invulnerability window, a short visual flash (scale change), and
// a simple knockback by setting the entity velocity when damaged.

///|
struct HealthEntry {
  entity : @system.Entity
  mut health : Int
  max_health : Int
  mut took_damage : Bool
  mut _last_damage : Int
  mut invuln_timer : Double
  mut flash_timer : Double
  mut knockback : @math.Vec2D
  _base_sprite : @sprite.Sprite?
}

///|
let health_components : Ref[Map[@system.Entity, HealthEntry]] = {
  val: Map::new(),
}

///|
// Health entry record fields:
// entity, health, max_health, took_damage, last_damage, invuln_timer,
// flash_timer, knockback_vec

///|
fn add_health(entity : @system.Entity, max_health : Int) -> Unit {
  let base_sprite = match @sprite.sprites.get(entity) {
    Some(s) => Some(s)
    None => None
  }
  let entry : HealthEntry = {
    entity,
    health: max_health,
    max_health,
    took_damage: false,
    _last_damage: 0,
    invuln_timer: 0.0,
    flash_timer: 0.0,
    knockback: @math.Vec2D(0.0, 0.0),
    _base_sprite: base_sprite,
  }
  health_components.val.set(entity, entry)
  // Debug: announce new health entry
  println(
    "add_health: entity=" +
    entity.to_string() +
    " health=" +
    max_health.to_string(),
  )
}

///|
fn set_invulnerability(entity : @system.Entity, duration : Double) -> Unit {
  match health_components.val.get(entity) {
    Some(entry_val) => {
      let mut entry = entry_val
      entry.invuln_timer = duration
      // if this is the player entity, also set the global player invuln timer used elsewhere
      guard game_state.player_entity is Some(pe) else { () }
      if pe == entity {
        game_state.player_invuln_timer = duration
      }
      health_components.val.set(entity, entry)
      entry = entry // Use mutability
    }
    None => {
      println("set_invuln: entity " + entity.to_string() + " not found in health_components")
    }
  }
}

///|
fn take_damage(
  entity : @system.Entity,
  amount : Int,
  source_pos : @math.Vec2D?,
) -> Unit {
  // Prioritize global player invulnerability as a workaround
  guard game_state.player_entity is Some(pe) else { () }
  if pe == entity && game_state.player_invuln_timer > 0.0 {
    println("take_damage: ignored due to global player_invuln_timer")
    return
  }

  match health_components.val.get(entity) {
    Some(entry_val) => {
      let mut entry = entry_val
      println(
        "take_damage: entity=" +
        entity.to_string() +
        " invuln=" +
        entry.invuln_timer.to_string() +
        " amount=" +
        amount.to_string(),
      )
      // check per-entity invuln
      if entry.invuln_timer > 0.0 {
        println(
          "take_damage: ignored due per-entity invuln for entity=" +
          entity.to_string(),
        )
        return
      }

      // apply damage directly
      let mut new_health = entry.health - amount
      if new_health < 0 {
        new_health = 0
      }
      entry.health = new_health
      entry.took_damage = true
      entry._last_damage = amount
      entry.invuln_timer = 1.0
      entry.flash_timer = 0.2
      match source_pos {
        Some(sp) => {
          guard @position.positions.get(entity) is Some(ent_pos) else { () }
          let dir = (ent_pos.0 - sp).normalize()
          let kb = dir.scalar_mul(200.0)
          entry.knockback = kb
          @velocity.velocities.set(entity, kb)
          @system.timeout(0.15, true, fn() {
            @velocity.velocities.set(entity, @math.Vec2D(0.0, 0.0))
          })

          // flash
          let flash_ent = @system.Entity::new()
          @position.positions.set(flash_ent, ent_pos.0)
          let tile_size : Double = 8.0
          let anim = @sprite.Animation::new(
            @sprite.frames_from_atlas(
              "assets/textures/heart-ui.png",
              1,
              width=tile_size,
              height=tile_size,
              offset=@math.Vec2D(0.0, 0.0),
            ),
            loop_=false,
            fps=0.0,
            transform=@math.Transform::from_scale(6.0, 6.0),
          )
          let spr = @sprite.Sprite::from_animation(anim, 100)
          @sprite.sprites.set(flash_ent, spr)
          @system.timeout(0.2, true, fn() { flash_ent.destroy() })
        }
        None => ()
      }
      health_components.val.set(entity, entry)
      entry = entry // Use mutability
    }
    None => ()
  }
}

///|
fn update_health_system(delta : Double) -> Unit {
  let mut dead_entities = []
  for entity in health_components.val.keys() {
    let mut e = health_components.val.get(entity).unwrap()
    if e.invuln_timer > 0.0 {
      e.invuln_timer = if e.invuln_timer - delta < 0.0 {
        0.0
      } else {
        e.invuln_timer - delta
      }
    }
    if e.flash_timer > 0.0 {
      e.flash_timer = if e.flash_timer - delta < 0.0 {
        0.0
      } else {
        e.flash_timer - delta
      }
    }
    if e.took_damage {
      // For player, synchronize global game_state.player_health
      guard game_state.player_entity is Some(player) else {  }
      if player == e.entity {
        // clamp to max_health and sync
        let clamped = if e.health > e.max_health {
          e.max_health
        } else {
          e.health
        }
        game_state.player_health = clamped
      }

      // If entity died, destroy and spawn light for enemies
      if e.health <= 0 && e.entity.is_alive() {
        // spawn light if enemy
        match @collision.collision_layers.get(e.entity) {
          Some(layer) =>
            if layer == enemy_collision_layer {
              guard @position.positions.get(e.entity) is Some(pos) else { () }
              let light = spawn_light(pos.0)
              game_state.lights.push(light)
            }
          None => ()
        }
        e.entity.destroy()
        dead_entities.push(entity)
      }
      e.took_damage = false
      e._last_damage = 0
    }
    health_components.val.set(entity, e)
    e = e // Use mutability
  }
  for entity in dead_entities {
    health_components.val.remove(entity)
  }
  dead_entities = dead_entities // Use mutability
}

///|
pub fn game_start(_delta : Double) -> Unit {
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

  // Initialize first wave after a short delay
  @system.timeout(1.0, true, fn() { start_wave() })
  // Initialize UI layer
  @Scenes.init_scene_ui(0.0)
}

///|
pub fn tick(_delta : Double) -> Unit {
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
pub fn wave_management_system(_delta : Double) -> Unit {
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
pub fn input_system(_delta : Double) -> Unit {
  // Toggle shop with T key (Tab not available)
  if @inputs.is_just_pressed(@inputs.KeyT) {
    println("T pressed - toggling shop")
    game_state.shop_open = not(game_state.shop_open)
  }
}

///|
pub fn enemy_shooting_system(_delta : Double) -> Unit {
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
pub fn player_move_system(delta : Double) -> Unit {
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
pub fn shooting_system(_delta : Double) -> Unit {
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
pub fn enemy_ai_system(_delta : Double) -> Unit {
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
        let speed = match enemy_infos.val.get(enemy) {
          Some(info) => info.speed
          None => ENEMY_SPEED
        }
        let velocity = direction.normalize().scalar_mul(speed)
        @velocity.velocities.set(enemy, velocity)
      }
    }
  }
}

///|
pub fn enemy_spawn_system(delta : Double) -> Unit {
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
    let safe_spawn_distance : Double = 200.0
    guard game_state.player_entity is Some(player) else { () }
    if @position.positions.get(player) is Some(player_pos) {
      println("spawn_enemy: player_pos: " + player_pos.0.to_string())
      println("spawn_enemy: initial spawn_pos: " + spawn_pos.to_string())
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
        println("spawn_enemy: new spawn_pos: " + new_pos.to_string())
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
