let meterStarted = false;
let isPassenger = false;
let lastFare = 0;
let lastDistance = 0;

function formatMoney(value) {
    return '$ ' + Math.floor(value || 0);
}

function formatDistance(meters) {
    return Math.floor(meters || 0) + ' M';
}

window.addEventListener('message', function(event) {
    const data = event.data;
    if (!data || !data.action) return;

    switch (data.action) {
        case "openUI":
            isPassenger = data.meterData?.isPassenger ?? false;
            showUI(data.meterData);
            break;

        case "closeUI":
            hideUI();
            break;

        case "startMeter":
            meterStarted = true;
            updateMeterState(true);
            break;

        case "stopMeter":
            meterStarted = false;
            updateMeterState(false);
            break;

        case "resetMeter":
            resetMeter();
            break;

        case "updateMeter":
            updateMeter(data.meterData);
            break;
    }
});

function showUI(data) {
    $('.container').fadeIn(150);

    $('#total-price').text(formatMoney(data.currentFare));
    $('#total-distance').text(formatDistance(data.distanceTraveled));

    $('#total-price-per-100m').text(formatMoney(data.defaultPrice));
    $('#total-price-per-100m-label').show();

    if (data.isPassenger) $(".toggle-meter-btn").hide();
    else $(".toggle-meter-btn").show();
}

function hideUI() {
    $('.container').fadeOut(150);
}

function updateMeterState(running) {
    if (isPassenger) return;
    const btn = $(".toggle-meter-btn p");
    btn.text(running ? "Bật" : "Tắt");
    btn.css("color", running ? "rgb(51,160,37)" : "rgb(231,30,37)");
}

function updateMeter(data) {
    const fare = Math.floor(data.currentFare ?? 0);
    const distance = Math.floor(data.distanceTraveled ?? 0);

    if (fare !== lastFare) {
        $('#total-price').text(formatMoney(fare));
        lastFare = fare;
    }
    if (distance !== lastDistance) {
        $('#total-distance').text(formatDistance(distance));
        lastDistance = distance;
    }
}

function resetMeter() {
    lastFare = 0;
    lastDistance = 0;
    $('#total-price').text('$ 0');
    $('#total-distance').text('0 M');
}
