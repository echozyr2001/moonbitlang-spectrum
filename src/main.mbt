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
  .run()
}

///|
fn game_start(_delta : Double) -> Unit {
  let p = spawn_player(
    @math.Vec2D(REAL_VIEWPORT_WIDTH / 2.0, REAL_VIEWPORT_HEIGHT / 2.0),
  )
  player_ref.val = Some(p)
}

///|
fn tick(_delta : Double) -> Unit {

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
    @position.positions.set(e, new_pos)
  }
}
