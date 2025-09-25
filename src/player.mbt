///|
pub fn spawn_player(pos : @math.Vec2D) -> @system.Entity {
  let e = @system.Entity::new()
  // Use Spectrum player slice at offset (24, 0) with 8x8, scaled to 64x64
  let tile_size : Double = 8.0
  let tile_offset : @math.Vec2D = @math.Vec2D(24.0, 0.0)
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
      // upscale to 64x64
      transform=@math.Transform::from_scale(8.0, 8.0),
    ),
    5,
    // center the sprite on its position
    offset=@math.Vec2D(-tile_size * 4.0, -tile_size * 4.0),
  )
  @sprite.sprites.set(e, sprite)
  @position.positions.set(e, pos)

  // Set up collision for player
  @collision.collision_layers.set(e, player_collision_layer)
  @collision.shapes.set(
    e,
    @collision.CollisionShape::Rect(
      size=@math.Vec2D(tile_size * 8.0, tile_size * 8.0),
      offset=@math.Vec2D(-tile_size * 4.0, -tile_size * 4.0),
    ),
  )

  // Set up area for light collection
  let collection_area = @collision.Area::new(
    @collision.CollisionMask::new([light_collision_layer]),
  )
  collection_area.on_enter(fn(light_entity) {
    if @collision.collision_layers.get(light_entity) ==
      Some(light_collision_layer) {
      // Collect light and add to score
      game_state.score += 1
      light_entity.destroy()
    }
  })
  @collision.areas.set(e, collection_area)
  // add health component for player
  add_health(e, 3)
  // give a short invulnerability immediately after spawn to avoid instant collisions
  set_invulnerability(e, 3.0)
  println(
    "spawn_player: set invulnerability for player entity=" + e.to_string(),
  )
  e
}
