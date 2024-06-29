
function begin(_event) {
    try {

        function display(msg) {
            document.getElementById("messages").innerText += '\n' + msg;
        }

        display("Test!...?");
        helloWorld(195).then(
            (value) => {
                display(value);
            }
        );

    } catch (error) {
        alert(error);
    }
}

// alert(webview);

window.onload = begin;