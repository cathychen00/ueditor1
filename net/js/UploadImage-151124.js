UploadImage = function (param) {
    Init = function () {
        new qq.FineUploaderBasic({
            button: document.getElementById(param.BttonId),
            request: {
                endpoint: param.Url
            },
            multiple: false,
            text: {
                uploadButton: "浏览..."
            },
            classes: {
                buttonHover: "",
                buttonFocus: ""
            },
            callbacks: {
                onComplete: UploadComplete,
                onUpload: param.beforeUpload ? function () { eval(param.beforeUpload); } : function () { }
            }
        });
    };

    UploadComplete = function (id, fileName, data) {
        if (data.Success == 0) {
            alert(data.Message);
        } else {
            var item = data.Body.FileList[0];
            
            if (item.Success) {
                var img1 = item.FilePath;
                if (param.Host == "") {
                    img1 = img1.replace(/http:\/\/www\d\.autoimg.cn\//ig, '');
                }
                jQuery("#" + param.Id).val(img1);
                jQuery("#" + param.HiddenId).val(img1);
                if (param.PreviewControlId) {
                    if (param.ShowHost == "") {
                        jQuery("#" + param.PreviewControlId).attr("src", img1);
                    } else {
                        jQuery("#" + param.PreviewControlId).attr("src", item.FilePath);
                    }
                }
                if (param.CallBack) {
                    var img = item.FilePath;
                    if (param.ShowHost == "") {
                        img = img.FilePath.replace(/http:\/\/www\d\.autoimg.cn\//ig, '');
                    }
                    eval(param.CallBack + "('" + img + "'," + item.Width + ", " + item.Height + ")");
                }
            } else {
                alert(item.Message);
            }
        }
    };
    Init();
};

var Auto = Auto || {};
Auto.ImageCommon = Auto.ImageCommon || {};
Auto.ImageCommon = {
    GetImageDomainNumber: function (imagepath) {
        imagepath = imagepath.substring(imagepath.lastIndexOf('/') + 1);
        var b = 0, i = 0;
        while ((i += 4) < imagepath.length) { b ^= imagepath.charCodeAt(i); }
        b %= 2;
        return b;
    },
    AddImgHosts: function (imagepath, hosts) {
        if (hosts == undefined) hosts = "www{0}.autoimg.cn";
        if (imagepath.indexOf('/') === 0) {
            imagepath = imagepath.substring(1);
        }
        var imagename = imagepath.substring(imagepath.lastIndexOf('/') + 1);
        var no = 0;
        if (imagepath.indexOf("autohomecar__") !== -1) {
            no = 2;
        }
        no += this.GetImageDomainNumber(imagepath);
        return ("http://" + hosts + "/" + imagepath).replace("{0}", no);
    }
}