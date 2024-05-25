
function begin(_event) {
    try {

        function display(msg) {
            document.getElementById("messages").innerText += '\n' + msg;
        }

        display("Test!...?");
        // my_binded_func(195).then(
        //     (value) => {
        //         display(value);
        //     }
        // );

    } catch (error) {
        alert(error);
    }
}

// alert(webview);

window.onload = begin;