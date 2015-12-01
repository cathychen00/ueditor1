<%@ WebHandler Language="C#" Class="HVideo" %>

using System;
using System.Web;

public class HVideo : IHttpHandler {
    
    public void ProcessRequest (HttpContext context) {
        context.Response.ContentType = "text/plain";
        //context.Response.Write("{\"returncode\":0,\"message\":\"成功!\",\"result\":{\"video\":{\"Id\":26523,\"YoukuVideoKey\":\"XNzExMDQ0NjMy\",\"AutoVideoKey\":\"\"}}}");
        context.Response.Write("{\"returncode\":0,\"message\":\"成功!\",\"result\":{\"video\":{\"Id\":26819,\"YoukuVideoKey\":\"\",\"AutoVideoKey\":\"4E38149A1E51922D\"}}}");
    }
 
    public bool IsReusable {
        get {
            return false;
        }
    }

}