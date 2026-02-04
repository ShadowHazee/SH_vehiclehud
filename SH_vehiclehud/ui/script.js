let lastShowState = false;

// Variables globales pour les clignotants
let indicatorInterval = null;
const indicatorSound = new Audio('sounds/IndicatorSound.mp3');
indicatorSound.volume = 0.2;

const hudElements = {
    hud: $('#vehicle-hud'),
    handle: $('.drag-handle'),
    
    // Indicateurs
    indLeft: $('#ind-left'),
    indRight: $('#ind-right'),
    
    // Vitesse & Moteur
    speedNumber: $('.speed-value .number'),
    speedUnit: $('.speed-value .unit'),
    gear: $('.gear-info .gear'),
    rpmFill: $('.rpm-fill'),
    rpmSegments: $('.segment'),
    
    // Essence
    fuelBar: $('.stat-bar.fuel .bar-fill'),
    fuelValue: $('.stat-bar.fuel .value.fuel-pc'),
    
    // Icones et Statuts
    seatbeltIcon: $('#seatbelt-icon'),
    seatbeltText: $('#seatbelt-text'),
    seatbeltBar: $('.stat-bar.seatbelt'),
    
    cruiseBar: $('.stat-bar.cruise'),
    cruiseText: $('#cruise-text'),
    
    // NOUVEAUX ÉLÉMENTS
    lockIcon: $('#lock-icon'),
    lockText: $('#lock-text'),
    lockBar: $('.stat-bar.lock'),
    
    direction: $('#direction'),
    street: $('#street-name')
};

$(function() {
    // Charger la position sauvegardée
    const savedPos = JSON.parse(localStorage.getItem('hudPosition'));
    if (savedPos) {
        hudElements.hud.css({
            'top': savedPos.top + 'px',
            'left': savedPos.left + 'px',
            'bottom': 'auto'
        });
    }

    // Drag and Drop (Déplacement du HUD)
    let isDragging = false;
    let offsetX, offsetY;

    hudElements.handle.on('mousedown', function(e) {
        if (!hudElements.hud.hasClass('edit-mode')) return;
        isDragging = true;
        offsetX = e.clientX - hudElements.hud.offset().left;
        offsetY = e.clientY - hudElements.hud.offset().top;
    });

    $(window).on('mousemove', function(e) {
        if (!isDragging) return;
        hudElements.hud.css({
            'left': (e.clientX - offsetX) + 'px',
            'top': (e.clientY - offsetY) + 'px',
            'bottom': 'auto'
        });
    });

    $(window).on('mouseup', function() {
        if (isDragging) {
            isDragging = false;
            localStorage.setItem('hudPosition', JSON.stringify({
                top: hudElements.hud.position().top,
                left: hudElements.hud.position().left
            }));
        }
    });

    // Clic bouton Valider (Mode Édition)
    $('#save-hud-btn').on('click', function() {
        hudElements.hud.removeClass('edit-mode');
        $.post(`https://${GetParentResourceName()}/closeEditMode`, JSON.stringify({}));
    });
});

window.addEventListener('message', (event) => {
    const data = event.data;
    
    if (data.type === 'updateVehicleHud') {
        // Récupération de toutes les données envoyées par le client.lua
        const { show, speed, gear, fuel, rpm, unit, seatbelt, cruise, lock, street, direction } = data;
        
        lastShowState = show;

        if (show || hudElements.hud.hasClass('edit-mode')) {
            hudElements.hud.fadeIn(200).removeClass('hidden');
            
            // Mise à jour Vitesse / RPM / Gear
            hudElements.speedNumber.text(speed);
            hudElements.speedUnit.text(unit ? unit.toUpperCase() : 'KM/H');
            hudElements.gear.text(gear === 0 ? 'R' : gear);
            updateRPM(rpm);

            // Mise à jour Essence
            hudElements.fuelBar.css('width', fuel + '%');
            hudElements.fuelValue.text(fuel + '%');
            
            // Mise à jour Ceinture
            if (seatbelt) {
                hudElements.seatbeltBar.addClass('active').removeClass('blink-red');
                hudElements.seatbeltIcon.removeClass('fa-user-slash').addClass('fa-user-shield');
                hudElements.seatbeltText.text('Attaché');
            } else {
                hudElements.seatbeltBar.removeClass('active');
                hudElements.seatbeltIcon.removeClass('fa-user-shield').addClass('fa-user-slash');
                hudElements.seatbeltText.text('Détaché');
            }
            
            // Mise à jour Limiteur
            if (cruise) hudElements.cruiseBar.addClass('active');
            else hudElements.cruiseBar.removeClass('active');

            // Mise à jour Verrouillage (NOUVEAU)
            if (lock === 1) { // 1 = Ouvert
                hudElements.lockBar.removeClass('locked').addClass('unlocked');
                hudElements.lockIcon.removeClass('fa-lock').addClass('fa-lock-open');
                hudElements.lockText.text('OUVERT');
            } else { // 2 = Fermé
                hudElements.lockBar.removeClass('unlocked').addClass('locked');
                hudElements.lockIcon.removeClass('fa-lock-open').addClass('fa-lock');
                hudElements.lockText.text('FERMÉ');
            }

            // Mise à jour Localisation (NOUVEAU)
            hudElements.direction.text(direction);
            hudElements.street.text(street);
            
        } else {
            hudElements.hud.fadeOut(200);
        }

    } else if (data.type === 'updateIndicators') {
        // Gestion des Clignotants
        const { left, right } = data;

        // Visuel (Classe CSS)
        if (left) hudElements.indLeft.addClass('active');
        else hudElements.indLeft.removeClass('active');

        if (right) hudElements.indRight.addClass('active');
        else hudElements.indRight.removeClass('active');

        // Audio (Boucle)
        if ((left || right) && !indicatorInterval) {
            indicatorSound.play().catch(e => {}); 
            indicatorInterval = setInterval(() => {
                indicatorSound.currentTime = 0;
                indicatorSound.play().catch(e => {});
            }, 600); 
        } else if (!left && !right && indicatorInterval) {
            clearInterval(indicatorInterval);
            indicatorInterval = null;
            indicatorSound.pause();
            indicatorSound.currentTime = 0;
        }

    } else if (data.type === 'toggleHudEdit') {
        hudElements.hud.toggleClass('edit-mode');
        if (hudElements.hud.hasClass('edit-mode')) hudElements.hud.fadeIn(200).removeClass('hidden');
        else if (!lastShowState) hudElements.hud.fadeOut(200);

    } else if (data.type === 'seatbeltAlert') {
        data.alert ? hudElements.seatbeltBar.addClass('blink-red') : hudElements.seatbeltBar.removeClass('blink-red');

    } else if (data.type === 'playSound') {
        let audio = new Audio('sounds/' + data.sound + '.mp3');
        audio.volume = data.volume || 0.1;
        audio.play().catch(e => console.log(e));

    } else if (data.type === 'hideVehicleHud') {
        if (!hudElements.hud.hasClass('edit-mode')) hudElements.hud.fadeOut(200);
    }
});

function updateRPM(rpm) {
    hudElements.rpmFill.css('width', (rpm * 100) + '%');
    hudElements.rpmSegments.each(function(index) {
        const pos = (index + 1) / hudElements.rpmSegments.length;
        if (rpm >= pos) {
            if (pos > 0.8) $(this).css('background-color', 'rgba(231, 76, 60, 0.8)');
            else if (pos > 0.6) $(this).css('background-color', 'rgba(241, 196, 15, 0.8)');
            else $(this).css('background-color', 'rgba(255, 255, 255, 0.8)');
        } else $(this).css('background-color', '');
    });
}