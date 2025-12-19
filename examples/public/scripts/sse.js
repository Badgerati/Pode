$(document).ready(() => {
    $('button#local').off('click').on('click', (e) => {
        const sse = new EventSource("/data");

        sse.addEventListener("Action", (e) => {
            console.log(`Action: ${e.data}`);
            $('#messages').append(`<p>Action: ${e.data}</p>`);
        });

        sse.addEventListener("BoldOne", (e) => {
            console.log(`BoldOne: ${e.data}`);
            $('#messages').append(`<p>BoldOne: ${e.data}</p>`);
        });

        sse.addEventListener("pode.close", (e) => {
            console.log('CLOSE');
            sse.close();
        });

        sse.addEventListener("pode.ping", (e) => {
            console.log('PING');
        });

        sse.addEventListener("pode.open", (e) => {
            var data = JSON.parse(e.data);
            console.log(`OPEN: ${data.clientId}`);
        });

        sse.onerror = (e) => {
            console.log(`ERROR! :: ${e}`);
            sse.close();
        }
    });

    $('button#global').off('click').on('click', (e) => {
        const sse2 = new EventSource("/sse");

        sse2.onmessage = (e) => {
            console.log(`MESSAGE2: ${e.data}`);
            $('#messages').append(`<p>${e.data}</p>`);
        };

        sse2.onerror = (e) => {
            console.log(`ERROR2! :: ${e}`);
            sse2.close();
        };

        sse2.addEventListener("pode.close", (e) => {
            console.log('CLOSE2');
            sse2.close();
        });

        sse2.addEventListener("pode.ping", (e) => {
            console.log('PING2');
        });

        sse2.addEventListener("pode.open", (e) => {
            var data = JSON.parse(e.data);
            console.log(`OPEN2: ${data.clientId}`);
        });
    });
})