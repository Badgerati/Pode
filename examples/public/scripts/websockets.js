$(document).ready(() => {
    // create the websocket
    var ws = new WebSocket("ws://localhost:8091/");

    // event for inbound messages to append them
    ws.onmessage = function(evt) {
        //var data = JSON.parse(evt.data)
        console.log(evt.data);
        $('#messages').append(`<p>${evt.data}</p>`);
    }

    // send message on the socket
    $('#bc-form').submit(function(e) {
        e.preventDefault();
        ws.send(JSON.stringify({ message: $('#bc-message').val() }));
        $('input[name=message]').val('')
    })
})