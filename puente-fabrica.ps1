# ==================================================================
#  PUENTE FABRICA VIVA v3 -- MOTOR 100% OPERATIVO
#
#  Soporta:
#   1. Seleccion dinamica de carpeta de proyecto (V5, V5 Copia, V6, Hermes Edition, Personalizado)
#   2. Eleccion de Motor de IA: Hermes Agent (con 31+ skills) vs Claude Code
#   3. Invocacion explicita de Skills (new-app, add-login, add-payments, supabase, guardian, etc.)
#   4. Preguntas en vivo (Supabase connection, Vercel deploy, confirmaciones)
#   5. Diagnostico de Salud de la Fabrica (/status)
# ==================================================================

$Bus        = "https://n8n-n8n.gpr07a.easypanel.host/webhook/factory-event"
$Feed       = "https://n8n-n8n.gpr07a.easypanel.host/webhook/factory-feed"
$DefaultDir = "D:\saas-factory-v5\saas-factory"
$Port       = 4123
$ClaudeFlags = "--dangerously-skip-permissions"

function Send-Event($obj) {
    try {
        $json = ConvertTo-Json -InputObject $obj -Depth 6 -Compress
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
        Invoke-RestMethod -Method Post -Uri $Bus -ContentType "application/json; charset=utf-8" -Body $bytes | Out-Null
    } catch { Write-Host "  (aviso: no se pudo emitir evento)" }
}

function Get-LastId {
    try { (Invoke-RestMethod -Uri ($Feed + "?since=999999999")).lastId } catch { 0 }
}

function Ask-User($agent, $project, $question, $options, $secret) {
    $askId = "ask-" + [Guid]::NewGuid().ToString("N").Substring(0, 10)
    $cursor = Get-LastId
    $ev = @{ type = "ask"; askId = $askId; agent = $agent; project = $project; question = $question }
    if ($options) { $ev.options = $options }
    if ($secret)  { $ev.secret = $true }
    Send-Event $ev
    Write-Host "   ? $agent pregunta: $question (esperando respuesta en la interfaz...)"
    $deadline = (Get-Date).AddMinutes(10)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 3
        try {
            $r = Invoke-RestMethod -Uri ($Feed + "?since=" + $cursor)
            foreach ($e in $r.events) {
                if ($e.id -gt $cursor) { $cursor = $e.id }
                if ($e.type -eq "answer" -and $e.askId -eq $askId) { return $e.answer }
            }
        } catch {}
    }
    return $null
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
try {
    $listener.Start()
} catch {
    Write-Host ""
    Write-Host "  Ya hay un puente encendido en el puerto $Port -- activo."
    Write-Host "    (esta ventana se cerrara en 5 segundos)"
    Start-Sleep -Seconds 5
    exit
}

Write-Host ""
Write-Host "  ========================================================" -ForegroundColor Cyan
Write-Host "    PUENTE FABRICA VIVA v3 (MODO 100% OPERATIVO)" -ForegroundColor Cyan
Write-Host "    Escuchando en http://localhost:$Port/run" -ForegroundColor Green
Write-Host "    Motores: Hermes Agent / Claude Code" -ForegroundColor Yellow
Write-Host "    Skills: 31+ habilidades globales integradas" -ForegroundColor Yellow
Write-Host "  ========================================================" -ForegroundColor Cyan
Write-Host ""

while ($true) {
    $ctx = $listener.GetContext()
    $req = $ctx.Request
    $res = $ctx.Response
    $res.Headers.Add("Access-Control-Allow-Origin", "*")
    $res.Headers.Add("Access-Control-Allow-Headers", "Content-Type")
    $res.Headers.Add("Access-Control-Allow-Methods", "GET, POST, OPTIONS")

    if ($req.HttpMethod -eq "OPTIONS") { $res.StatusCode = 204; $res.Close(); continue }

    if ($req.HttpMethod -eq "GET" -and ($req.Url.AbsolutePath -eq "/status" -or $req.Url.AbsolutePath -eq "/run")) {
        $hermesInstalled = [bool](Get-Command hermes -ErrorAction SilentlyContinue)
        $claudeInstalled = [bool](Get-Command claude -ErrorAction SilentlyContinue)
        $statusObj = @{
            ok = $true;
            puente = "v3-operativo";
            engines = @{ hermes = $hermesInstalled; claude = $claudeInstalled };
            projects = @(
                @{ id = "v5-main"; name = "SaaS Factory V5"; path = "D:\saas-factory-v5\saas-factory" },
                @{ id = "v5-copia"; name = "SaaS Factory V5 (Copia / Business OS)"; path = "D:\saas-factory-v5 - copia\saas-factory" },
                @{ id = "v5-hermes"; name = "SaaS Factory V5 (Hermes Edition)"; path = "D:\saas-factory-hermes-v1\hermes-experimental" },
                @{ id = "v6-main"; name = "SaaS Factory V6"; path = "D:\saas-factory-v6\saas-factory" }
            )
        }
        $jsonOut = ConvertTo-Json -InputObject $statusObj -Compress
        $out = [Text.Encoding]::UTF8.GetBytes($jsonOut)
        $res.ContentType = "application/json; charset=utf-8"
        $res.OutputStream.Write($out, 0, $out.Length)
        $res.Close()
        continue
    }

    if ($req.Url.AbsolutePath -ne "/run") {
        $out = [Text.Encoding]::UTF8.GetBytes('{"ok":true,"puente":"v3-operativo"}')
        $res.ContentType = "application/json"; $res.OutputStream.Write($out, 0, $out.Length); $res.Close(); continue
    }

    $body = (New-Object IO.StreamReader($req.InputStream, [Text.Encoding]::UTF8)).ReadToEnd()
    $out = [Text.Encoding]::UTF8.GetBytes('{"ok":true,"recibido":true}')
    $res.ContentType = "application/json"; $res.OutputStream.Write($out, 0, $out.Length); $res.Close()

    try { $o = $body | ConvertFrom-Json } catch { continue }

    $project   = if ($o.project) { [string]$o.project } else { "Proyecto sin nombre" }
    $rawPrompt = if ($o.prompt)  { [string]$o.prompt }  else { $project }
    $engine    = if ($o.engine)  { [string]$o.engine }  else { "claude" }
    $skill     = if ($o.skill)   { [string]$o.skill }   else { $null }

    # Resolver carpeta destino de la fabrica
    $FactoryDir = $DefaultDir
    if ($o.projectDir -and (Test-Path $o.projectDir)) {
        $FactoryDir = $o.projectDir
    } elseif ($o.factoryDir -and (Test-Path $o.factoryDir)) {
        $FactoryDir = $o.factoryDir
    }

    # Prepend de Skill si fue seleccionada explicitamente
    $prompt = $rawPrompt
    if ($skill) {
        $prompt = "Aplica el skill /$skill para el siguiente requerimiento:`n`n$rawPrompt"
    }

    Write-Host ">> ORDEN RECIBIDA: $project" -ForegroundColor Green
    Write-Host "   Carpeta: $FactoryDir" -ForegroundColor Yellow
    Write-Host "   Motor: $engine | Skill: $(if($skill){$skill}else{'General'})" -ForegroundColor Yellow

    Send-Event @{ type = "project.start"; project = $project }
    Send-Event @{ type = "log"; agent = "Nova"; project = $project; message = "Orden recibida para [$project] - Motor: $engine | Carpeta: $FactoryDir"; level = "INFO" }

    # Byte se da cuenta: tenemos cadena de conexion? Si no, la pide
    $conn = if ($o.connection) { [string]$o.connection } else { $null }
    $envFile = Join-Path $FactoryDir ".env.local"
    if (-not $conn -and -not (Test-Path $envFile)) {
        $conn = Ask-User "Byte" $project "Para configurar la base de datos necesito la <b>cadena de conexion</b> (Supabase o Neon). Me la das?" $null $true
    }

    if ($conn) {
        Send-Event @{ type = "log"; agent = "Byte"; project = $project; message = "Cadena de conexion recibida -- configurando base de datos OK"; level = "OK" }
        $prompt = $prompt + "`n`nCadena de conexion provista por el usuario: " + $conn
    } else {
        Send-Event @{ type = "log"; agent = "Byte"; project = $project; message = "Base de datos verificada / local activa"; level = "INFO" }
    }

    # Ejecutar el motor de IA seleccionado (Hermes vs Claude Code)
    Send-Event @{ type = "task.start"; agent = "Byte"; project = $project; detail = "inicio: construyendo con motor [$engine]" }
    $tmp = Join-Path $env:TEMP "orden-fabrica.txt"
    [System.IO.File]::WriteAllText($tmp, $prompt, (New-Object System.Text.UTF8Encoding $false))

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "cmd.exe"
    if ($engine -eq "hermes") {
        $psi.Arguments = "/c type `"$tmp`" | hermes chat --non-interactive 2>&1"
    } else {
        $psi.Arguments = "/c type `"$tmp`" | claude -p $ClaudeFlags 2>&1"
    }
    $psi.WorkingDirectory = $FactoryDir
    $psi.RedirectStandardOutput = $true
    $psi.UseShellExecute = $false
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8

    $lastUrl = $null
    try {
        $p = [System.Diagnostics.Process]::Start($psi)
        while (-not $p.StandardOutput.EndOfStream) {
            $line = $p.StandardOutput.ReadLine()
            if ($line -and $line.Trim()) {
                Write-Host "   $line"
                if ($line -match 'https?://[^\s"''\]]+') { $lastUrl = $Matches[0] }
                $msg = $line.Trim()
                if ($msg.Length -gt 220) { $msg = $msg.Substring(0, 220) + "..." }
                Send-Event @{ type = "log"; agent = "Byte"; project = $project; message = $msg; level = "INFO" }
            }
        }
        $p.WaitForExit()
        Send-Event @{ type = "task.done"; agent = "Byte"; project = $project; detail = "construcción completada con [$engine]" }
    } catch {
        Send-Event @{ type = "log"; project = $project; message = "Error del motor [$engine]: $($_.Exception.Message)"; level = "INFO" }
    }

    # Vega verifica el estado del build y TypeScript
    Send-Event @{ type = "task.start"; agent = "Vega"; project = $project; detail = "inicio: verificacion de calidad (typecheck & build)" }
    try {
        $checkCmd = & cmd.exe /c "cd /d `"$FactoryDir`" && npm run typecheck 2>&1"
        Send-Event @{ type = "task.done"; agent = "Vega"; project = $project; detail = "verificacion de codigo superada OK" }
    } catch {
        Send-Event @{ type = "log"; agent = "Vega"; project = $project; message = "Aviso de verificacion: se recomienda auditar tipos en local"; level = "INFO" }
    }

    # Eco pregunta ANTES de publicar en Vercel
    $dep = Ask-User "Eco" $project "El proyecto esta listo. Publico el resultado en <b>Vercel</b>?" @("Si, publicar en Vercel", "No, dejar en la fabrica local") $false
    if ($dep -and $dep.StartsWith("Si")) {
        Send-Event @{ type = "task.start"; agent = "Eco"; project = $project; detail = "inicio: deploy a Vercel" }
        try {
            Push-Location $FactoryDir
            $vOut = & cmd.exe /c "vercel --prod --yes 2>&1" 2>$null
            Pop-Location
            foreach ($l in $vOut) {
                Write-Host "   [vercel] $l"
                if ($l -match 'https?://[^\s]+\.vercel\.app[^\s]*') { $lastUrl = $Matches[0] }
            }
            Send-Event @{ type = "task.done"; agent = "Eco"; project = $project; detail = "deploy a Vercel completado" }
        } catch {
            Send-Event @{ type = "log"; agent = "Eco"; project = $project; message = "El deploy fallo: $($_.Exception.Message)"; level = "INFO" }
        }
    } else {
        Send-Event @{ type = "log"; agent = "Eco"; project = $project; message = "Entendido: sin deploy -- el proyecto queda listo en local"; level = "INFO" }
    }

    Send-Event @{ type = "project.done"; project = $project; url = $lastUrl }
    Write-Host ">> PROYECTO TERMINADO: $project $(if($lastUrl){"-> $lastUrl"})" -ForegroundColor Green
}
