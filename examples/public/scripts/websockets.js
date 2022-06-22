$(document).ready(() => {
    // create the websocket
    var ws = new WebSocket("ws://localhost:8091/");

    // event for inbound messages to append them
    ws.onmessage = function(evt) {
        var data = JSON.parse(evt.data)
        console.log(data);
        $('#messages').append(`<p>${data.message}</p>`);
    }

    // send message on the socket, to all clients
    $('#bc-form').submit(function(e) {
        e.preventDefault();
        console.log(`send: ${$('#bc-message').val()}`);
        ws.send(JSON.stringify({ message: $('#bc-message').val() }));
        $('input[name=message]').val('');
    })
})