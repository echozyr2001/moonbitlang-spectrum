///|
pub fn enter_game_scene(_delta : Double) -> Unit {
  // Preload textures by referencing them via the sprite helpers. Many Selene
  // implementations lazily load when first referenced by a sprite function;
  // calling frames_from_atlas is a simple, side-effectful way to ensure the
  // runtime has parsed the atlas and queued the texture for loading.
  ignore(
    @sprite.frames_from_atlas(
      "assets/textures/entities.png",
      1,
      width=8.0,
      height=8.0,
      offset=@math.Vec2D(0.0, 0.0),
    ),
  )
  ignore(
    @sprite.frames_from_atlas(
      "assets/textures/power-ups.png",
      1,
      width=8.0,
      height=8.0,
      offset=@math.Vec2D(0.0, 0.0),
    ),
  )
  ignore(
    @sprite.frames_from_atlas(
      "assets/textures/heart-ui.png",
      1,
      width=8.0,
      height=8.0,
      offset=@math.Vec2D(0.0, 0.0),
    ),
  )

  // Preload audio via selene `@audio.play_audio` helper found in selene-core
  // wrapper (it forwards to backend). Use volume and looping as desired.
  @audio.play_audio("assets/music/game-track.mp3", volume=0.5, loop_=true)
}

///|
pub fn exit_game_scene(_delta : Double) -> Unit {
  // No-op: stopping audio is left to the project's audio system. Replace
  // with @audio.* calls if your selene provides them.
}
