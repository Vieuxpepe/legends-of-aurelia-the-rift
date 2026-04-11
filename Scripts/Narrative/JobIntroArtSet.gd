extends Resource
class_name JobIntroArtSet

## Must match [member ClassData.job_name] exactly (e.g. [code]Fire Sage[/code], [code]Spellblade[/code]).
@export var job_name: String = "Mercenary"
## Shown on lines N, 2N, 3N… of that job's intro (N = [code]job_intro_illustration_interval[/code] on the story scene). Shorter arrays cycle for later beats.
@export var beat_textures: Array[Texture2D] = []
