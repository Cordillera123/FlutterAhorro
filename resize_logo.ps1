# Script para redimensionar el logo a diferentes tamaños
Add-Type -AssemblyName System.Drawing

function Resize-Image {
    param(
        [string]$InputPath,
        [string]$OutputPath,
        [int]$Width,
        [int]$Height
    )
    
    try {
        $img = [System.Drawing.Image]::FromFile($InputPath)
        $newImg = New-Object System.Drawing.Bitmap($Width, $Height)
        $graphics = [System.Drawing.Graphics]::FromImage($newImg)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.DrawImage($img, 0, 0, $Width, $Height)
        
        # Crear directorio si no existe
        $dir = Split-Path $OutputPath
        if (!(Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force
        }
        
        $newImg.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
        
        $graphics.Dispose()
        $newImg.Dispose()
        $img.Dispose()
        
        Write-Host "Creado: $OutputPath ($Width x $Height)"
    }
    catch {
        Write-Host "Error creando $OutputPath : $($_.Exception.Message)"
    }
}

$logoPath = "assets\images\logo.png"

if (Test-Path $logoPath) {
    Write-Host "Redimensionando logo a diferentes tamaños..."
    
    # Para íconos de la app (cuadrados)
    Resize-Image $logoPath "assets\icons\app_icon_512.png" 512 512
    Resize-Image $logoPath "assets\icons\app_icon_256.png" 256 256
    Resize-Image $logoPath "assets\icons\app_icon_192.png" 192 192
    Resize-Image $logoPath "assets\icons\app_icon_144.png" 144 144
    Resize-Image $logoPath "assets\icons\app_icon_96.png" 96 96
    Resize-Image $logoPath "assets\icons\app_icon_72.png" 72 72
    Resize-Image $logoPath "assets\icons\app_icon_48.png" 48 48
    
    # Ícono principal para flutter_launcher_icons
    Resize-Image $logoPath "assets\icons\app_icon.png" 1024 1024
    
    # Para diferentes tamaños en la app
    Resize-Image $logoPath "assets\images\logo_small.png" 64 64
    Resize-Image $logoPath "assets\images\logo_medium.png" 128 128
    Resize-Image $logoPath "assets\images\logo_large.png" 256 256
    
    # Logo para splash screen
    Resize-Image $logoPath "assets\images\logo_splash.png" 200 200
    
    Write-Host "Redimensionamiento completado!"
    Write-Host ""
    Write-Host "Archivos creados:"
    Get-ChildItem "assets\icons\*.png" | ForEach-Object { 
        $size = (Get-ItemProperty $_.FullName).Length
        Write-Host "   $($_.Name) - $([math]::Round($size/1KB, 1)) KB"
    }
    Get-ChildItem "assets\images\*.png" | ForEach-Object { 
        $size = (Get-ItemProperty $_.FullName).Length
        Write-Host "   $($_.Name) - $([math]::Round($size/1KB, 1)) KB"
    }
}
else {
    Write-Host "No se encontro el archivo logo.png en assets\images\"
}