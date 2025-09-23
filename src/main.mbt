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
  .run()
}

///|
fn game_start(_delta : Double) -> Unit {

}

///|
fn tick(_delta : Double) -> Unit {

}
