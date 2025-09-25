# Script para generar todos los tamaños desde la nueva imagen JPG
Add-Type -AssemblyName System.Drawing

function Resize-Image {
    param(
        [string]$InputPath,
        [string]$OutputPath,
        [int]$Width,
        [int]$Height,
        [string]$Format = "Png"
    )
    
    try {
        $img = [System.Drawing.Image]::FromFile($InputPath)
        $newImg = New-Object System.Drawing.Bitmap($Width, $Height)
        $graphics = [System.Drawing.Graphics]::FromImage($newImg)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.DrawImage($img, 0, 0, $Width, $Height)
        
        # Crear directorio si no existe
        $dir = Split-Path $OutputPath
        if (!(Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force
        }
        
        # Guardar según el formato especificado
        if ($Format -eq "Jpg") {
            $newImg.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Jpeg)
        } else {
            $newImg.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
        }
        
        $graphics.Dispose()
        $newImg.Dispose()
        $img.Dispose()
        
        Write-Host "Creado: $OutputPath ($Width x $Height)"
    }
    catch {
        Write-Host "Error creando $OutputPath : $($_.Exception.Message)"
    }
}

$newImage = "assets\icons\new_icon_image.jpg"

if (Test-Path $newImage) {
    Write-Host "Generando todas las imagenes desde new_icon_image.jpg..."
    
    # Para iconos de la app (cuadrados) - PNG para mejor calidad
    Resize-Image $newImage "assets\icons\app_icon_512.png" 512 512 "Png"
    Resize-Image $newImage "assets\icons\app_icon_256.png" 256 256 "Png"
    Resize-Image $newImage "assets\icons\app_icon_192.png" 192 192 "Png"
    Resize-Image $newImage "assets\icons\app_icon_144.png" 144 144 "Png"
    Resize-Image $newImage "assets\icons\app_icon_96.png" 96 96 "Png"
    Resize-Image $newImage "assets\icons\app_icon_72.png" 72 72 "Png"
    Resize-Image $newImage "assets\icons\app_icon_48.png" 48 48 "Png"
    
    # Icono principal para flutter_launcher_icons
    Resize-Image $newImage "assets\icons\app_icon.png" 1024 1024 "Png"
    
    # Para diferentes tamaños en la app - JPG para mantener el fondo
    Resize-Image $newImage "assets\images\logo_small.jpg" 64 64 "Jpg"
    Resize-Image $newImage "assets\images\logo_medium.jpg" 128 128 "Jpg"
    Resize-Image $newImage "assets\images\logo_large.jpg" 256 256 "Jpg"
    Resize-Image $newImage "assets\images\logo.jpg" 200 200 "Jpg"
    
    # Logo para splash screen
    Resize-Image $newImage "assets\images\logo_splash.jpg" 200 200 "Jpg"
    
    Write-Host ""
    Write-Host "Generacion completada!"
    Write-Host "Archivos creados:"
    Get-ChildItem "assets\icons\*.png" | ForEach-Object { 
        $size = (Get-ItemProperty $_.FullName).Length
        Write-Host "   $($_.Name) - $([math]::Round($size/1KB, 1)) KB"
    }
    Get-ChildItem "assets\images\*.jpg" | ForEach-Object { 
        $size = (Get-ItemProperty $_.FullName).Length
        Write-Host "   $($_.Name) - $([math]::Round($size/1KB, 1)) KB"
    }
}
else {
    Write-Host "No se encontro new_icon_image.jpg"
}