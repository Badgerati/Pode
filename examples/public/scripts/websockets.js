$(document).ready(() => {
    connectGlobally();
    connectLocally();
})

function connectGlobally() {
    // create a new websocket connection
    var ws = new WebSocket("ws://localhost:8091/msg");

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
    })
}

function connectLocally() {
    $('button#local').off('click').on('click', (e) => {
        // create a new websocket connection - will only live for the duration of the request
        var ws = new WebSocket("ws://localhost:8091/local");

        // event for inbound messages to append them
        ws.onmessage = function(evt) {
            var data = JSON.parse(evt.data)
            console.log(data);
            $('#messages').append(`<p>${data.message}</p>`);
        }
    });
}