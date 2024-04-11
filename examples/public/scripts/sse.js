$(document).ready(() => {
    $('button#local').off('click').on('click', (e) => {
        const sse = new EventSource("/data");

        sse.addEventListener("Action", (e) => {
            $('#messages').append(`<p>Action: ${e.data}</p>`);
        });

        sse.addEventListener("BoldOne", (e) => {
            $('#messages').append(`<p>BoldOne: ${e.data}</p>`);
        });

        sse.addEventListener("pode.close", (e) => {
            console.log('CLOSE');
            sse.close();
        });

        sse.addEventListener("pode.open", (e) => {
            var data = JSON.parse(e.data);
            console.log(`OPEN: ${data.clientId}`);
        });

        sse.onerror = (e) => {
            console.log('ERROR!');
        }
    });

    $('button#global').off('click').on('click', (e) => {
        const sse2 = new EventSource("/sse");

        sse2.onmessage = (e) => {
            $('#messages').append(`<p>${e.data}</p>`);
        };

        sse2.onerror = (e) => {
            console.log('ERROR2!');
            sse.close();
        };

        sse2.addEventListener("pode.close", (e) => {
            console.log('CLOSE');
            sse2.close();
        });
    });
})