// ==UserScript==
// @name         KuGouSignIn
// @namespace    http://tampermonkey.net/
// @version      1.0.1
// @description  kugou music sign in automatically
// @author       little star & zkysimon
// @source       https://zky.gs
// @match        https://*/*
// @icon         https://www.kugou.com/yy/static/images/play/logo.png
// @grant        GM_setValue
// @grant        GM_getValue
// @grant        GM_xmlhttpRequest
// @require      http://ajax.aspnetcdn.com/ajax/jQuery/jquery-3.1.0.min.js
// @require      https://cdn.jsdelivr.net/gh/zkysimon/script@latest/kugou/md5.js
// ==/UserScript==

if (GM_getValue('KuGousignInfo') != new Date().getDay())
    signInfo();

function signInfo() {
    var cookie = "";
    var kugouid = cookie.match(/KugooID=(\S*)&Ku/)[1];
    var token = cookie.match(/&t=(\S*)&a/)[1];
    var time = new Date().valueOf();
    var arr = new Array(9);

    arr[0] = "appid=1014";
    arr[1] = "token=" + token;
    arr[2] = "kugouid=" + kugouid;
    arr[3] = "srcappid=2919";
    arr[4] = "clientver=20000";
    arr[5] = "clienttime=" + time;
    arr[6] = "mid=" + time;
    arr[7] = "uuid=" + time;
    arr[8] = "dfid=-";
    arr.sort();

    var str = "NVPh5oo715z5DIWAeQlhMDsWXXQV4hwt";
    for (var i = 0; i < arr.length; i++) {
        str = str + arr[i];
    }
    str = str + "NVPh5oo715z5DIWAeQlhMDsWXXQV4hwt";

    var signature = hex_md5(str).toUpperCase();

    var address = "https://h5activity.kugou.com/v1/musician/do_signed?appid=1014"
                + "&token=" + token
                + "&kugouid=" + kugouid
                + "&srcappid=2919&clientver=20000"
                + "&clienttime=" + time
                + "&mid=" + time
                + "&uuid=" + time
                + "&dfid=-"
                + "&signature=" + signature;

    GM_xmlhttpRequest({
        method: "post",
        url: address,
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        onload: function (r) {
            var errcode = r.responseText.match(/"errcode":(\S*)}/)[1];
            if (errcode == 0) {
                GM_setValue('KuGousignInfo', new Date().getDay());
                var signedTimes = r.responseText.match(/"signed_times":(\S*),"notice"/)[1];
                if (signedTimes == 3) {
                    alert(new Date().toLocaleDateString() + "酷狗音乐人签到成功，恭喜您已经领取7天vip。");
                }
                else {
                    alert(new Date().toLocaleDateString() + "酷狗音乐人签到成功，您已连续签到" + signedTimes + "天。")
                }
            }
            else {
                var errmsg = r.responseText.match(/"errmsg":"(\S*)"}/)[1];
                alert(new Date().toLocaleDateString() + "酷狗音乐人签到失败，因为"+errmsg+".");
            }
        }
    });
}
