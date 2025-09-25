# Script para limpiar el fondo transparente del logo
Add-Type -AssemblyName System.Drawing

function Add-WhiteBackground {
    param(
        [string]$InputPath,
        [string]$OutputPath
    )
    
    try {
        # Cargar la imagen original
        $originalImg = [System.Drawing.Image]::FromFile($InputPath)
        
        # Crear una nueva imagen del mismo tamaño con fondo blanco
        $newImg = New-Object System.Drawing.Bitmap($originalImg.Width, $originalImg.Height)
        $graphics = [System.Drawing.Graphics]::FromImage($newImg)
        
        # Rellenar con fondo blanco
        $graphics.Clear([System.Drawing.Color]::White)
        
        # Dibujar la imagen original encima
        $graphics.DrawImage($originalImg, 0, 0, $originalImg.Width, $originalImg.Height)
        
        # Guardar la nueva imagen
        $newImg.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
        
        # Limpiar recursos
        $graphics.Dispose()
        $newImg.Dispose()
        $originalImg.Dispose()
        
        Write-Host "Fondo limpio agregado: $OutputPath"
    }
    catch {
        Write-Host "Error procesando $InputPath : $($_.Exception.Message)"
    }
}

# Procesar todas las imágenes del logo
$logoFiles = @(
    "assets\images\logo.png",
    "assets\images\logo_small.png",
    "assets\images\logo_medium.png", 
    "assets\images\logo_large.png",
    "assets\images\logo_splash.png"
)

Write-Host "Limpiando fondos transparentes..."

foreach ($file in $logoFiles) {
    if (Test-Path $file) {
        # Crear backup
        $backupFile = $file -replace "\.png$", "_backup.png"
        Copy-Item $file $backupFile -Force
        
        # Limpiar fondo
        Add-WhiteBackground $file $file
    }
}

Write-Host "Fondos limpiados. Backups creados con _backup.png"