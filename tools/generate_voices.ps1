# Renders the voice callout clips with the Windows speech voices installed on this
# machine, then encodes them to .ogg with ffmpeg.
# Keep $Callouts in sync with the callout keys in AlertCCOnMe/Data/CastableCC.lua (the
# offline tests check the built-in packs).
#   Built-in packs into AlertCCOnMe/Media/Voice/<Pack>/:
#     powershell -ExecutionPolicy Bypass -File tools/generate_voices.ps1
#   One pack for a voice pack add-on (see templates/AlertCCOnMe_Voice_Example):
#     ... -File tools/generate_voices.ps1 -Name Grampa -Voice "Microsoft David Desktop" -OutDir <addon>\Voice
param(
	[string]$Name,
	[string]$Voice,
	[string]$OutDir
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$out = Join-Path $root "AlertCCOnMe\Media\Voice"
# A private temp folder per run, so nothing else can swap a clip between render and encode.
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("accm_voice_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force $tmp | Out-Null

$Callouts = [ordered]@{
	Sheep = "Sheep"; Cyclone = "Cyclone"; Hibernate = "Hibernate"; Roots = "Roots"
	Sleep = "Sleep"; Fear = "Fear"; Seduction = "Seduction"; Banish = "Banish"
	MindControl = "Mind control"; Shackle = "Shackle"; Hex = "Hex"; Lasso = "Lasso"
	TurnEvil = "Turn evil"; ScareBeast = "Scare beast"; SongOfChiJi = "Song of Chee-Jee"
	CC = "Crowd control"; Cast = "Cast"
}

# Desktop SAPI voices (System.Speech) and OneCore voices (WinRT) are separate catalogs.
$Packs = @(
	@{ Name = "David"; Engine = "sapi"; Voice = "Microsoft David Desktop" },
	@{ Name = "Zira"; Engine = "sapi"; Voice = "Microsoft Zira Desktop" },
	@{ Name = "Mark"; Engine = "winrt"; Voice = "Microsoft Mark" }
)

Add-Type -AssemblyName System.Speech
$sapi = New-Object System.Speech.Synthesis.SpeechSynthesizer

if ($Voice) {
	if (-not ($Name -and $OutDir)) { throw "-Voice needs -Name and -OutDir" }
	$isSapi = $sapi.GetInstalledVoices() | Where-Object { $_.VoiceInfo.Name -eq $Voice }
	$Packs = @(@{ Name = $Name; Engine = $(if ($isSapi) { "sapi" } else { "winrt" }); Voice = $Voice; Dir = $OutDir })
}

$null = [Windows.Media.SpeechSynthesis.SpeechSynthesizer, Windows.Media.SpeechSynthesis, ContentType = WindowsRuntime]
$null = [Windows.Storage.Streams.DataReader, Windows.Storage.Streams, ContentType = WindowsRuntime]
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$asTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
	$_.Name -eq "AsTask" -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq "IAsyncOperation``1"
} | Select-Object -First 1
function Await($op, [Type]$type) {
	$task = $asTask.MakeGenericMethod($type).Invoke($null, @($op))
	$task.Wait() | Out-Null
	$task.Result
}
$winrt = New-Object Windows.Media.SpeechSynthesis.SpeechSynthesizer

function Render($pack, $text, $wav) {
	if ($pack.Engine -eq "sapi") {
		$sapi.SelectVoice($pack.Voice)
		$sapi.Rate = 2
		$sapi.SetOutputToWaveFile($wav)
		$sapi.Speak($text)
		$sapi.SetOutputToNull()
	} else {
		$voice = [Windows.Media.SpeechSynthesis.SpeechSynthesizer]::AllVoices | Where-Object { $_.DisplayName -eq $pack.Voice } | Select-Object -First 1
		if (-not $voice) { throw "voice not installed: $($pack.Voice)" }
		$winrt.Voice = $voice
		$winrt.Options.SpeakingRate = 1.25
		$stream = Await ($winrt.SynthesizeTextToStreamAsync($text)) ([Windows.Media.SpeechSynthesis.SpeechSynthesisStream])
		$reader = New-Object Windows.Storage.Streams.DataReader($stream.GetInputStreamAt(0))
		$size = [uint32]$stream.Size
		Await ($reader.LoadAsync($size)) ([uint32]) | Out-Null
		$bytes = New-Object byte[] $size
		$reader.ReadBytes($bytes)
		[IO.File]::WriteAllBytes($wav, $bytes)
	}
}

foreach ($pack in $Packs) {
	$dir = $(if ($pack.Dir) { $pack.Dir } else { Join-Path $out $pack.Name })
	New-Item -ItemType Directory -Force $dir | Out-Null
	foreach ($key in $Callouts.Keys) {
		$name = $Callouts[$key]
		foreach ($variant in @(@{ Suffix = "OnYou"; Text = "$name on you!" }, @{ Suffix = ""; Text = "$name!" })) {
			$wav = Join-Path $tmp "clip.wav"
			Render $pack $variant.Text $wav
			$ogg = Join-Path $dir "$key$($variant.Suffix).ogg"
			# Trim leading/trailing silence so the callout starts the instant it fires.
			& ffmpeg -loglevel error -y -i $wav -af "silenceremove=start_periods=1:start_threshold=-50dB,areverse,silenceremove=start_periods=1:start_threshold=-50dB,areverse,loudnorm=I=-14:TP=-1" -ac 1 -ar 44100 -c:a libvorbis -q:a 4 $ogg
			if ($LASTEXITCODE -ne 0) { throw "ffmpeg failed for $ogg" }
		}
	}
	Write-Output "$($pack.Name): $((Get-ChildItem $dir -Filter *.ogg).Count) clips"
}
Remove-Item -Recurse -Force $tmp
