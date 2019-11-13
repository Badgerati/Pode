$(document).ready(() => {
    // bind submit on the form to send message to the server
    $('#bc-form').submit(function(e) {
        e.preventDefault();

        $.ajax({
            url: '/broadcast',
            type: 'post',
            data: $('#bc-form').serialize()
        })

        $('input[name=message]').val('')
    })

    // create the websocket
    var ws = new WebSocket("ws://localhost:8091/");

    // event for inbound messages to append them
    ws.onmessage = function(evt) {
        var data = JSON.parse(evt.data)
        $('#messages').append(`<p>${data.Message}</p>`);
    }
})