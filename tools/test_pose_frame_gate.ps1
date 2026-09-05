param(
    [string]$GradleCache = (Join-Path $env:USERPROFILE '.gradle/caches/modules-2/files-2.1'),
    [string]$Java = 'java'
)

# Uses the project's already-resolved Kotlin compiler, without adding JUnit,
# downloading dependencies, or requiring an Android device.
$ErrorActionPreference = 'Stop'
function Find-CachedJar([string]$RelativeDirectory) {
    $directory = Join-Path $GradleCache $RelativeDirectory
    $jar = Get-ChildItem -LiteralPath $directory -Filter '*.jar' -Recurse |
        Select-Object -First 1
    if ($null -eq $jar) { throw "Missing cached compiler dependency: $RelativeDirectory. Run the Android build first." }
    return $jar.FullName
}

$compilerJars = @(
    (Find-CachedJar 'org.jetbrains.kotlin/kotlin-compiler-embeddable/2.2.20'),
    (Find-CachedJar 'org.jetbrains.kotlin/kotlin-stdlib/2.2.20'),
    (Find-CachedJar 'org.jetbrains.kotlin/kotlin-script-runtime/2.2.20'),
    (Find-CachedJar 'org.jetbrains.kotlin/kotlin-reflect/1.6.10'),
    (Find-CachedJar 'org.jetbrains.kotlin/kotlin-daemon-embeddable/2.2.20'),
    (Find-CachedJar 'org.jetbrains.kotlinx/kotlinx-coroutines-core-jvm/1.8.0'),
    (Find-CachedJar 'org.jetbrains/annotations/23.0.0')
)
$compilerClasspath = $compilerJars -join [System.IO.Path]::PathSeparator
$projectDirectory = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$testOutput = Join-Path $projectDirectory 'build/pose-native-tests'
New-Item -ItemType Directory -Force -Path $testOutput | Out-Null
$gate = Join-Path $projectDirectory 'android/app/src/main/kotlin/com/example/flutter_body/pose/PoseFrameGate.kt'
$checks = Join-Path $projectDirectory 'android/app/src/test/kotlin/com/example/flutter_body/pose/PoseFrameGateCheck.kt'

& $Java -cp $compilerClasspath org.jetbrains.kotlin.cli.jvm.K2JVMCompiler `
    -no-stdlib -no-reflect -classpath $compilerClasspath -d $testOutput $gate $checks
if ($LASTEXITCODE -ne 0) { throw 'Native frame gate test compilation failed.' }

$runtimeClasspath = $testOutput + [System.IO.Path]::PathSeparator + $compilerClasspath
& $Java -cp $runtimeClasspath com.example.flutter_body.pose.PoseFrameGateCheckKt
if ($LASTEXITCODE -ne 0) { throw 'Native frame gate checks failed.' }
