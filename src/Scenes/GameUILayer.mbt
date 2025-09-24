///|
fn init_ui() -> Unit {
  // Create HUD entities and set text sprites using Selene ECS-style UI.
  // Health
  let health_ent = @system.Entity::new()
  @position.positions.set(health_ent, @math.Vec2D(20.0, 20.0))
  let health_text = @sprite.Text::new("Health: 0")
  let health_sprite = @sprite.Sprite::from_text(health_text, @ui.UI_ZINDEX)
  @sprite.sprites.set(health_ent, health_sprite)
  @ui.uis.set(health_ent, @ui.Ui::new())
  // Store refs so update_hud can replace sprites later
  health_ent_ref.val = Some(health_ent)

  // Lights / score
  let lights_ent = @system.Entity::new()
  @position.positions.set(lights_ent, @math.Vec2D(20.0, 48.0))
  let lights_text = @sprite.Text::new("Lights: 0")
  let lights_sprite = @sprite.Sprite::from_text(lights_text, @ui.UI_ZINDEX)
  @sprite.sprites.set(lights_ent, lights_sprite)
  @ui.uis.set(lights_ent, @ui.Ui::new())
  lights_ent_ref.val = Some(lights_ent)

  // FPS
  let fps_ent = @system.Entity::new()
  @position.positions.set(fps_ent, @math.Vec2D(20.0, 76.0))
  let fps_text = @sprite.Text::new("FPS: 0")
  let fps_sprite = @sprite.Sprite::from_text(fps_text, @ui.UI_ZINDEX)
  @sprite.sprites.set(fps_ent, fps_sprite)
  @ui.uis.set(fps_ent, @ui.Ui::new())
  fps_ent_ref.val = Some(fps_ent)
}

// Module-level refs so main can call update_hud to refresh UI elements.

///|
let health_ent_ref : Ref[@system.Entity?] = { val: None }

///|
let lights_ent_ref : Ref[@system.Entity?] = { val: None }

///|
let fps_ent_ref : Ref[@system.Entity?] = { val: None }

///|
// Update HUD with explicit values. This avoids cross-package mutation and
// keeps the Scenes package independent of main's game_state layout.
pub fn update_hud(health : Int, score : Int, fps : Int) -> Unit {
  match health_ent_ref.val {
    Some(ent) => {
      let new_health_text = @sprite.Text::new("Health: " + health.to_string())
      @sprite.sprites.set(
        ent,
        @sprite.Sprite::from_text(new_health_text, @ui.UI_ZINDEX),
      )
    }
    None => ()
  }
  match lights_ent_ref.val {
    Some(ent) => {
      let new_lights_text = @sprite.Text::new("Lights: " + score.to_string())
      @sprite.sprites.set(
        ent,
        @sprite.Sprite::from_text(new_lights_text, @ui.UI_ZINDEX),
      )
    }
    None => ()
  }
  match fps_ent_ref.val {
    Some(ent) => {
      let new_fps_text = @sprite.Text::new("FPS: " + fps.to_string())
      @sprite.sprites.set(
        ent,
        @sprite.Sprite::from_text(new_fps_text, @ui.UI_ZINDEX),
      )
    }
    None => ()
  }
}

///|
// Expose a small init function to be called from main or a scene enter system.
pub fn init_scene_ui(_d : Double) -> Unit {
  init_ui()
}
