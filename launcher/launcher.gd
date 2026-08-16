extends Node2D
## Word Wars launcher.
##
## Checks the GitHub releases API, downloads the build for this platform if it is
## newer than what is installed, unpacks it and runs it. Friends keep this one
## file; everything after that updates itself.
##
## Deliberately dumb and stable: it cannot update *itself* (nothing can replace a
## running executable on Windows), so the less reason it ever has to change, the
## better. It knows only a repo name and an asset naming convention.

const REPO := "DamonDJr/word-wars"
const API := "https://api.github.com/repos/%s/releases/latest" % REPO
const STATE := "user://installed.cfg"
const INSTALL_DIR := "user://game"

## Asset to fetch per platform, and the executable expected inside it.
const BUILDS := {
	"Windows": {"asset": "WordWars-windows-x86_64.zip", "exe": "WordWars.exe"},
	"Linux": {"asset": "WordWars-linux-x86_64.zip", "exe": "WordWars.x86_64"},
}

enum Step { CHECKING, DOWNLOADING, UNPACKING, READY, PLAYING, FAILED }

var step: int = Step.CHECKING
var status := "checking for updates"
var detail := ""
var installed := ""
var latest := ""
var progress := 0.0

var _http: HTTPRequest
var _zip_path := ""
var _asset_url := ""
var _font: Font
var _font_bold: Font
var _spin := 0.0


func _ready() -> void:
	_font = ThemeDB.fallback_font
	var fv := FontVariation.new()
	fv.base_font = _font
	fv.variation_embolden = 0.6
	_font_bold = fv

	_http = HTTPRequest.new()
	_http.use_threads = true
	add_child(_http)
	_http.request_completed.connect(_on_http)

	DirAccess.make_dir_recursive_absolute(INSTALL_DIR)
	installed = _read_installed()

	if not BUILDS.has(OS.get_name()):
		_fail("no build for %s" % OS.get_name(), "Windows and Linux only for now.")
		return
	_check()


# --------------------------------------------------------------------- update

func _check() -> void:
	step = Step.CHECKING
	status = "checking for updates"
	detail = "installed: %s" % (installed if installed != "" else "nothing yet")
	# The API is happier with a User-Agent, and asking for the v3 media type
	# keeps the response shape stable.
	var err := _http.request(API, [
		"Accept: application/vnd.github+json",
		"User-Agent: WordWarsLauncher",
	])
	if err != OK:
		_offline_fallback("could not reach GitHub")


func _on_http(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if step == Step.CHECKING:
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			_offline_fallback("GitHub said %d" % code)
			return
		var parsed = JSON.parse_string(body.get_string_from_utf8())
		if typeof(parsed) != TYPE_DICTIONARY:
			_offline_fallback("could not read the release")
			return

		latest = String(parsed.get("tag_name", ""))
		var want: String = BUILDS[OS.get_name()]["asset"]
		for a in parsed.get("assets", []):
			if String(a.get("name", "")) == want:
				_asset_url = String(a.get("browser_download_url", ""))
				break

		if _asset_url == "":
			_offline_fallback("release %s has no %s" % [latest, want])
			return
		if latest == installed and _game_exe_exists():
			status = "up to date"
			detail = latest
			_ready_to_play()
			return
		_download()
		return

	if step == Step.DOWNLOADING:
		if result != HTTPRequest.RESULT_SUCCESS or code >= 400:
			_offline_fallback("download failed (%d)" % code)
			return
		_unpack()


func _download() -> void:
	step = Step.DOWNLOADING
	status = "downloading %s" % latest
	detail = "this only happens when something changes"
	progress = 0.0
	_zip_path = "user://download.zip"
	_http.download_file = _zip_path
	var err := _http.request(_asset_url, ["User-Agent: WordWarsLauncher"])
	if err != OK:
		_offline_fallback("could not start the download")


func _unpack() -> void:
	step = Step.UNPACKING
	status = "unpacking"
	detail = ""
	_http.download_file = ""

	var zip := ZIPReader.new()
	if zip.open(_zip_path) != OK:
		_fail("the download was unreadable", "Try again, or grab the zip by hand.")
		return

	# Replace the old install rather than merging into it, so a file that
	# disappears upstream does not linger here forever.
	_wipe(INSTALL_DIR)
	DirAccess.make_dir_recursive_absolute(INSTALL_DIR)

	# Unpacked with its directories intact rather than flattened into one folder.
	# This used to take `name.get_file()` and drop everything into INSTALL_DIR,
	# which was harmless while a build was a single executable and is a trap now
	# that it carries native libraries: a shared object the game loads by
	# relative path stops being findable the moment its folder is thrown away.
	# The current exports happen to be flat, so this is guarding against the next
	# one rather than fixing today — but the failure it guards against is a game
	# that installs without complaint and then will not start.
	for name in zip.get_files():
		if name.ends_with("/"):
			continue
		var out := "%s/%s" % [INSTALL_DIR, name]
		var sub := out.get_base_dir()
		if sub != INSTALL_DIR:
			DirAccess.make_dir_recursive_absolute(sub)
		var f := FileAccess.open(out, FileAccess.WRITE)
		if f == null:
			zip.close()
			_fail("could not write %s" % name.get_file(), "Check disk space.")
			return
		f.store_buffer(zip.read_file(name))
		f.close()
	zip.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_zip_path))

	# Zip files carry no permission bits worth trusting, so set the bit we need.
	if OS.get_name() != "Windows":
		OS.execute("chmod", ["+x", _game_exe()])

	installed = latest
	_write_installed(latest)
	status = "updated to %s" % latest
	detail = ""
	_ready_to_play()


## Losing the network is not a reason to stop somebody playing what they have.
func _offline_fallback(why: String) -> void:
	if _game_exe_exists():
		status = "playing offline"
		detail = "%s — running installed %s" % [why, installed]
		_ready_to_play()
	else:
		_fail(why, "Nothing installed yet, so there is nothing to fall back on.")


func _ready_to_play() -> void:
	step = Step.READY
	# Straight into the game; the launcher is not somewhere anyone wants to sit.
	await get_tree().create_timer(0.6).timeout
	_play()


func _play() -> void:
	var exe := _game_exe()
	if not FileAccess.file_exists(exe):
		_fail("the game is missing", "Delete the launcher's data folder and retry.")
		return
	step = Step.PLAYING
	status = "starting Word Wars"
	if OS.create_process(exe, []) <= 0:
		_fail("could not start the game", exe)
		return
	await get_tree().create_timer(0.4).timeout
	get_tree().quit()


func _fail(what: String, why: String) -> void:
	step = Step.FAILED
	status = what
	detail = why


# ---------------------------------------------------------------------- disk

func _game_exe() -> String:
	return ProjectSettings.globalize_path(
		"%s/%s" % [INSTALL_DIR, BUILDS[OS.get_name()]["exe"]])


func _game_exe_exists() -> bool:
	return FileAccess.file_exists(_game_exe())


func _wipe(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)


func _read_installed() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(STATE) != OK:
		return ""
	return String(cfg.get_value("game", "version", ""))


func _write_installed(tag: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "version", tag)
	cfg.save(STATE)


# -------------------------------------------------------------------- drawing

func _process(delta: float) -> void:
	_spin += delta
	if step == Step.DOWNLOADING:
		var total := _http.get_body_size()
		if total > 0:
			progress = clampf(float(_http.get_downloaded_bytes()) / float(total), 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color("#0b1020"), true)
	var cx := size.x * 0.5

	_centered(_font_bold, Vector2(cx, 92.0), "WORD WARS", 46, Color("#e6ecff"))
	_centered(_font, Vector2(cx, 126.0), "launcher", 14, Color("#7c88ad"))

	var tint := Color("#7bdff2")
	if step == Step.FAILED:
		tint = Color("#ff6b6b")
	elif step == Step.READY or step == Step.PLAYING:
		tint = Color("#ffd166")
	_centered(_font_bold, Vector2(cx, 196.0), status, 18, tint)
	if detail != "":
		_centered(_font, Vector2(cx, 222.0), detail, 12, Color("#7c88ad"))

	# A bar while downloading, a drifting sweep while merely waiting.
	var bar := Rect2(cx - 190.0, 254.0, 380.0, 6.0)
	draw_rect(bar, Color("#1a2140"), true)
	if step == Step.DOWNLOADING and progress > 0.0:
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * progress, bar.size.y)), tint, true)
		_centered(_font, Vector2(cx, 280.0), "%d%%" % int(progress * 100.0), 12,
			Color("#7c88ad"))
	elif step == Step.CHECKING or step == Step.DOWNLOADING or step == Step.UNPACKING:
		var w := 90.0
		var x := cx - 190.0 + fmod(_spin * 150.0, 380.0 + w) - w
		draw_rect(Rect2(maxf(x, bar.position.x),
			bar.position.y,
			minf(w, bar.end.x - maxf(x, bar.position.x)), bar.size.y), tint, true)

	if step == Step.FAILED:
		_centered(_font, Vector2(cx, 300.0),
			"github.com/%s/releases" % REPO, 12, Color("#5d6a92"))


func _centered(font: Font, at: Vector2, text: String, size: int, color: Color) -> void:
	if font == null or text == "":
		return
	var m := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	draw_string(font, Vector2(at.x - m.x * 0.5, at.y - m.y * 0.5 + font.get_ascent(size)),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
