// ==UserScript==
// @name         KuGouLogIn&SignIn
// @namespace    http://tampermonkey.net/
// @version      1.5.1
// @description  KuGou Music log in and sign in automatically
// @match        https://*/*
// @icon         https://www.kugou.com/yy/static/images/play/logo.png
// @grant        GM_setValue
// @grant        GM_getValue
// @grant        GM_xmlhttpRequest
// @require      http://ajax.aspnetcdn.com/ajax/jQuery/jquery-3.1.0.min.js
// @require      https://cdn.jsdelivr.net/gh/zkysimon/script@latest/kugou/md5.js
// ==/UserScript==

var username = "";    //酷狗id，请前往 https://www.kugou.com/newuc/user/uc/ 登陆并查看。
var md5password = "";    //密码，请前往 https://md5jiami.bmcx.com/ 加密，32位大写。
var mid = "";    //kg_mid，音乐人界面获取的cookie中的第一项。
var token;

if (GM_getValue('KuGousignInfo') != new Date().getDay()) {
    login();
}

function login() {
    var time = new Date().valueOf();
    var params = "https://login-user.kugou.com/v1/login/?appid=1058"
               + "&username=" + username
               + "&pwd=" + md5password
               + "&code=&ticket=&clienttime=" + time
               + "&expire_day=60&autologin=false&redirect_uri=&state=&callback=loginModule.loginCallback"
               + "&login_ver=1&mobile=&mobile_code=&plat=4&dfid=-"
               + "&mid=" + mid
               + "&kguser_jv=180925";

    GM_xmlhttpRequest({
        method: "get",
        url: params,
        headers: {
            "User-agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.131 Safari/537.36 Edg/92.0.902.73",
            "Content-Type": "application/x-www-form-urlencoded",
            "Accept": "application/atom+xml,application/xml,text/xml",
            "referer": "https://m3ws.kugou.com/"
        },
        onload: function (r) {
            var errorcode = r.responseText.indexOf("errorCode");

            if (errorcode == -1) {
                token = r.responseText.match(/"token":"(\S*)",/)[1];
                signInfo(token);
            }
            else {
                alert("酷狗音乐人登录失败。");
            }
        }
    })
}

function signInfo(logintoken) {

    var kugouid = username;
    var time = new Date().valueOf();
    var arr = new Array(9);
    arr[0] = "appid=1058";
    arr[1] = "token=" + logintoken;
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

    var address = "https://h5activity.kugou.com/v1/musician/do_signed?appid=1058"
                + "&token=" + logintoken
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
                alert(new Date().toLocaleDateString() + "酷狗音乐人签到失败，因为" + errmsg + "。");
            }
        }
    });
}
