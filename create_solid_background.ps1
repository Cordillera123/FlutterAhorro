# Script para crear versiones con fondo sólido del logo
Add-Type -AssemblyName System.Drawing

function Add-BackgroundToImage {
    param(
        [string]$InputPath,
        [string]$OutputPath,
        [int]$Red = 255,
        [int]$Green = 255,
        [int]$Blue = 255
    )
    
    try {
        $originalImg = [System.Drawing.Image]::FromFile($InputPath)
        
        # Crear una nueva imagen con fondo sólido
        $newImg = New-Object System.Drawing.Bitmap($originalImg.Width, $originalImg.Height)
        $graphics = [System.Drawing.Graphics]::FromImage($newImg)
        
        # Llenar con color de fondo
        $backgroundColor = [System.Drawing.Color]::FromArgb($Red, $Green, $Blue)
        $brush = New-Object System.Drawing.SolidBrush($backgroundColor)
        $graphics.FillRectangle($brush, 0, 0, $originalImg.Width, $originalImg.Height)
        
        # Dibujar la imagen original encima
        $graphics.DrawImage($originalImg, 0, 0)
        
        # Crear directorio si no existe
        $dir = Split-Path $OutputPath
        if (!(Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force
        }
        
        $newImg.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
        
        $graphics.Dispose()
        $brush.Dispose()
        $newImg.Dispose()
        $originalImg.Dispose()
        
        Write-Host "Creado: $OutputPath con fondo sólido"
    }
    catch {
        Write-Host "Error procesando $InputPath : $($_.Exception.Message)"
    }
}
}

# Procesar todas las imágenes del logo con fondo blanco
$logoFiles = @(
    "assets\images\logo.png",
    "assets\images\logo_small.png", 
    "assets\images\logo_medium.png",
    "assets\images\logo_large.png",
    "assets\images\logo_splash.png"
)

Write-Host "Agregando fondo blanco a los logos..."

foreach ($file in $logoFiles) {
    if (Test-Path $file) {
        $newName = $file -replace "\.png$", "_solid.png"
        Add-BackgroundToImage $file $newName 255 255 255
    }
}

Write-Host "Conversión completada!"
Write-Host ""
Write-Host "Archivos con fondo sólido creados:"
Get-ChildItem "assets\images\*_solid.png" | ForEach-Object { 
    $size = (Get-ItemProperty $_.FullName).Length
    Write-Host "   $($_.Name) - $([math]::Round($size/1KB, 1)) KB"
}