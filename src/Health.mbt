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
  base_sprite : @sprite.Sprite?
}

///|
let health_components : Ref[Array[HealthEntry]] = { val: [] }

///|
// Health entry record fields:
// entity, health, max_health, took_damage, last_damage, invuln_timer,
// flash_timer, knockback_vec

///|
pub fn add_health(entity : @system.Entity, max_health : Int) -> Unit {
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
    base_sprite,
  }
  health_components.val.push(entry)
}

///|
fn find_entry_idx(entity : @system.Entity) -> Int {
  let mut i = 0
  for entry in health_components.val {
    if entry.entity == entity {
      return i
    }
    i += 1
  }
  -1
}

///|
pub fn take_damage(
  entity : @system.Entity,
  amount : Int,
  source_pos : @math.Vec2D?,
) -> Unit {
  let idx = find_entry_idx(entity)
  if idx < 0 {
    return
  }
  let mut entry = health_components.val[idx]
  if entry.invuln_timer > 0.0 {
    return
  }
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
      entry.knockback = dir.scalar_mul(200.0)
      @velocity.velocities.set(entity, entry.knockback)

      // clear knockback after 0.15s
      @system.timeout(0.15, true, fn() {
        @velocity.velocities.set(entity, @math.Vec2D(0.0, 0.0))
      })

      // spawn a small hit flash at entity position (uses heart-ui texture)
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

  // touch the variable to ensure mutability is considered used
  entry = entry
  health_components.val[idx] = entry
}

///|
pub fn update_health_system(delta : Double) -> Unit {
  let mut i = 0
  for entry in health_components.val {
    let mut e = entry
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
      }
      e.took_damage = false
      e._last_damage = 0
    }

    // touch the variable to ensure mutability is considered used
    e = e
    health_components.val[i] = e
    i += 1
  }
}
