<%@ WebHandler Language="C#" Class="UploadImage" %>
using System;
using System.Web;
using System.Collections.Generic;
using Autohome.CMS.Common;
using Autohome.CMS.Common.Extend;
using Autohome.CMS.Common.IO.Configs;
using Autohome.CMS.Common.IO.Configs.Model;
using Autohome.CMS.Common.IO.Upload;
using Autohome.CMS.Common.IO.Upload.Model;
using Autohome.CMS.Common.DateTimes;
using Autohome.CMS.Common.Json;

public class UploadImage : IHttpHandler
{
    int userId;
    public void ProcessRequest(HttpContext context)
    {
        var json = new OutJsonString { Message = "成功", Success = 1 };
        try
        {
            //if (!User.CheckUser(out userId))
            //{
            //    json.Message = "失败";
            //    json.Success = 0;
            //}
            string operType = AutoRequest.GetString("OperType", true);
            switch (operType)
            {
                case "GetUploadTypes":
                    GetUploadTypes(json);
                    break;
                case "UploadPicture":
                    UploadPicture(json);
                    break;
                default:
                    json.Success = 0;
                    json.Message = "传递参数出错OperType:" + operType;
                    break;
            }
        }
        catch (Exception ex)
        {
            //FileHelper.Append(@"$RootPath\Logs\TempPicture\$Year\$Month\$Day\" + CurrentUser.UserRealName + @"_4.log", ex.Message);
            json.Success = 0;
            json.Message = ex.Message;
            //LogHelper.LogError("传图失败", ex, HttpContext.Current.Request);
        }

        json.ToString().WriteEnd();
    }

    #region 根据Key获取相应配置信息 public void GetUploadTypes(OutJsonString json)
    /// <summary>
    /// 根据Key获取相应配置信息
    /// </summary>
    /// <param name="json">输出Json</param>
    public void GetUploadTypes(OutJsonString json)
    {
        string keys = AutoRequest.GetString("Keys");
        var list = new List<object>();
        foreach (var pairs in LoadConfig.UploadPicture.GetPictureSettings())
        {
            var dic = new JsonObject();
            if (string.IsNullOrWhiteSpace(keys))
            {
                dic.Add("Key", pairs.Value.Key);
                dic.Add("Text", pairs.Value.Text);
                dic.Add("Alt", pairs.Value.Alt);
                list.Add(dic);
            }
            else
            {
                foreach (string key in keys.Split(','))
                {
                    if (key == pairs.Value.Key)
                    {
                        dic.Add("Key", pairs.Value.Key);
                        dic.Add("Text", pairs.Value.Text);
                        dic.Add("Alt", pairs.Value.Alt);
                        list.Add(dic);
                    }
                }
            }
        }

        json.Body.Add("UploadConfigs", list);
    }
    #endregion

    #region 上传图片 public void UploadPicture(OutJsonString json)
    /// <summary>
    /// 上传图片
    /// </summary>
    /// <param name="json">输出Json</param>
    public void UploadPicture(OutJsonString json)
    {
        var key = AutoRequest.GetString("Key");
        var size = AutoRequest.GetInt("Size", 1);
        var site = AutoRequest.GetInt("Site", 3);
        var hostType = AutoRequest.GetInt("hostType", 1);
        var hostString = AutoRequest.GetString("host");
        var num = AutoRequest.GetInt("num");

        if (key.IsNullOrWhiteSpace())
        {
            json.Success = 0;
            json.Message = "参数[Key]不符合规则!";
            //LogHelper.LogInfo("参数[Key]不符合规则!,key:" + key);
        }
        else
        {
            var httpPostedImages = UploadHttpFileHelper.GetPostedImages();
            if (null == httpPostedImages || httpPostedImages.Count == 0)
            {
                json.Success = 0;
                json.Message = "上传文件个数不能为空!";
                //LogHelper.LogInfo("上传文件个数不能为空!");
            }
            else
            {
                ItemPictureSetting pitem = LoadConfig.UploadPicture.GetPictureSetting(key);//获取相应配置
                if (pitem.IsNull())
                {
                    json.Success = 0;
                    json.Message = "获取上传图片配置失败或获取节点失败!";
                    //LogHelper.LogError("获取上传图片配置失败或获取节点失败!", null, HttpContext.Current.Request, "key:" + key);
                }
                else
                {
                    var itemConfigList = new List<ItemConfigPicture>();//集合                
                    foreach (var httpPostedImage in httpPostedImages)
                    {
                        var itemConfig = new ItemConfigPicture() { Success = true };//单个文件
                        itemConfig.InputName = httpPostedImage.InputName;

                        ChkUploadPicture(httpPostedImage, pitem, itemConfig);//验证

                        List<ConfigPicture> pictureList = null;
                        if (itemConfig.Success)
                        {
                            pictureList = new List<ConfigPicture>();
                            DateTime dtime = DateTimeParse.Now();
                            foreach (PictureSetting fileSet in pitem.FileSettings)//尺寸循环
                            {
                                var configPicture = new ConfigPicture()
                                {
                                    PictureSingle = SavePicture.Single(httpPostedImage, fileSet, dtime, null),
                                    FileSetting = fileSet
                                };
                                pictureList.Add(configPicture);
                            }

                            //FileHelper.Append(@"$RootPath\Logs\TempPicture\$Year\$Month\$Day\" + CurrentUser.UserRealName + @"_1.log",
                            //    string.Format("{0}:{1} ", num, picture_list[0].PictureSingle.FilePath));
                        }

                        itemConfig.ConfigPictures = pictureList;
                        itemConfigList.Add(itemConfig);
                    }

                    DataItemPicture(json, size, itemConfigList, site, hostType, hostString);//上传完后其它的操作
                }
            }
        }
    }
    #endregion

    #region 对上传所有图片后处理 public void DataItemPicture(OutJsonString json, int size, List<ItemConfigPicture> list, int site)
    /// <summary>
    /// 对上传所有图片后处理
    /// </summary>
    /// <param name="json">输出Json</param>        
    /// <param name="list">上传图片信息集合</param>
    /// <param name="size">获取相应尺寸</param>
    /// <param name="hostType">返回路径是否加入主机头 0不</param>
    /// <param name="hostString">自定义主机头</param>
    public void DataItemPicture(OutJsonString json, int size, List<ItemConfigPicture> list, int site, int hostType, string hostString)
    {
        List<ResultPicture> resultItem_list = new List<ResultPicture>();//输出集合信息
        SavePicture.UpdateFileSeting(list);
        foreach (ItemConfigPicture itemConfigPicture in list)
        {
            ResultPicture item = new ResultPicture();
            item.Success = itemConfigPicture.Success;
            item.Message = itemConfigPicture.Message;
            item.InputName = itemConfigPicture.InputName;

            if (itemConfigPicture.Success)
            {
                foreach (ConfigPicture p in itemConfigPicture.ConfigPictures)
                {
                    if (null == p.PictureSingle) continue;

                    #region 插入数据库

                    //if (p.FileSetting.InsertDataSize)
                    //{
                    //    UpdateOriginalImg(userId, Config.AutoImgHost0 + p.PictureSingle.FilePath, p.PictureSingle.Width,
                    //                      p.PictureSingle.Height);
                    //}

                    //输出信息
                    if (p.PictureSingle.PictureSetting.Width == size)
                    {
                        if (hostType == 1)
                        {
                            item.FilePath = Autohome.CMS.Common.Picture.ImageCommon.AddImageDomain(p.PictureSingle.FilePath);
                        }
                        else
                        {
                            item.FilePath = p.PictureSingle.FilePath;
                        }

                        item.Width = p.PictureSingle.Width;
                        item.Height = p.PictureSingle.Height;
                        item.ActualWidth = p.PictureSingle.ActualWidth;
                        item.ActualHeight = p.PictureSingle.ActualHeight;
                    }


                    #endregion
                }
            }

            resultItem_list.Add(item);
        }

        json.Body.Add("FileList", resultItem_list);
    }
    #endregion

    #region 根据尺寸得到相应尺寸信息 public ConfigPicture GetResultPicture(ItemConfigPicture itemConfigPicture, int size)
    /// <summary>
    /// 根据尺寸得到相应尺寸信息
    /// </summary>
    /// <param name="list">上传图片信息集合</param>
    /// <param name="size">尺寸</param>
    /// <returns></returns>
    public ConfigPicture GetResultPicture(ItemConfigPicture itemConfigPicture, int size)
    {
        if (null != itemConfigPicture)
        {
            if (itemConfigPicture.Success)
            {
                foreach (ConfigPicture p in itemConfigPicture.ConfigPictures)
                {
                    if (size == p.FileSetting.Width) return p;
                }
            }
        }

        return null;
    }
    #endregion

    #region 验证 public void ChkUploadPicture(HttpPostedImage httpPostedImage, ItemPictureSetting fileSet, ItemConfigPicture itemConfig)
    /// <summary>
    /// 验证
    /// </summary>
    /// <param name="json"></param>
    /// <param name="httpPostedImage"></param>
    /// <param name="fileSet"></param>
    /// <param name="itemConfig"></param>
    public void ChkUploadPicture(HttpPostedImage httpPostedImage, ItemPictureSetting fileSet, ItemConfigPicture itemConfig)
    {
        if (!itemConfig.Success) return;
        if (!httpPostedImage.IsPicture)
        {
            itemConfig.Success = false;
            itemConfig.Message = httpPostedImage.Message;
            return;
        }

        if ((string.Concat(",", fileSet.Format, ",").IndexOf(string.Concat(",", httpPostedImage.Extension, ","), StringComparison.InvariantCultureIgnoreCase) == -1))
        {
            itemConfig.Success = false;
            itemConfig.Message = string.Format("图片正确格式是:{0} 现格式是:{1}", fileSet.Format, httpPostedImage.Extension);
            return;
        }

        if (fileSet.IsProportion)
        {
            if (fileSet.LimitWidth > 0 && fileSet.LimitHeight > 0)
            {
                if (httpPostedImage.Width * fileSet.LimitHeight != httpPostedImage.Height * fileSet.LimitWidth)
                {
                    itemConfig.Success = false;
                    itemConfig.Message = string.Format("图片限宽高比例：{0}:{1} 现比例：{2}:{3}", fileSet.LimitWidth, fileSet.LimitHeight, httpPostedImage.Width, httpPostedImage.Height);
                    return;
                }
            }
            else
            {
                itemConfig.Success = false;
                itemConfig.Message = "配置节点[LimitWidth]或[LimitHeight]为空";
                return;
            }
        }
        else
        {
            switch (fileSet.LimitWidthHeight)
            {
                case LimitValue.Min:
                    {
                        if (fileSet.LimitWidth > 0 && fileSet.LimitWidth > httpPostedImage.Width)
                        {
                            itemConfig.Success = false;
                            itemConfig.Message = string.Format("图片限宽度最小值是:{0} 现宽度是:{1}", fileSet.LimitWidth, httpPostedImage.Width);
                            return;
                        }
                        if (fileSet.LimitHeight > 0 && fileSet.LimitHeight > httpPostedImage.Height)
                        {
                            itemConfig.Success = false;
                            itemConfig.Message = string.Format("图片限高度最小值是:{0} 现高度是:{1}", fileSet.LimitHeight, httpPostedImage.Height);
                            return;
                        }
                        break;
                    }
                case LimitValue.Max:
                    {
                        if (fileSet.LimitWidthMax > 0 && fileSet.LimitWidthMax < httpPostedImage.Width)
                        {
                            itemConfig.Success = false;
                            itemConfig.Message = string.Format("图片限宽度最大值是:{0} 现宽度是:{1}", fileSet.LimitWidthMax, httpPostedImage.Width);
                            return;
                        }
                        if (fileSet.LimitHeightMax > 0 && fileSet.LimitHeightMax < httpPostedImage.Height)
                        {
                            itemConfig.Success = false;
                            itemConfig.Message = string.Format("图片限高度最大值是:{0} 现高度是:{1}", fileSet.LimitHeightMax, httpPostedImage.Height);
                            return;
                        }
                        break;
                    }
                case LimitValue.MinMax:
                    {
                        if (fileSet.LimitWidthMax > 0 && fileSet.LimitHeightMax > 0 && (
                            fileSet.LimitWidth > httpPostedImage.Width || fileSet.LimitHeight > httpPostedImage.Height ||
                            fileSet.LimitWidthMax < httpPostedImage.Width || fileSet.LimitHeightMax < httpPostedImage.Height)
                            )
                        {
                            itemConfig.Success = false;
                            itemConfig.Message = string.Format(@"图片限宽限高最小最大值：宽度最小值{0} 宽度最大值是:{1}; 高度最小值{2} 高度最大值{3}; 现宽度是:{4} 现高度是:{5}",
                                fileSet.LimitWidth, fileSet.LimitWidthMax, fileSet.LimitHeight, fileSet.LimitHeightMax, httpPostedImage.Width, httpPostedImage.Height);
                            return;
                        }
                        break;
                    }
                default:
                    {
                        if (fileSet.LimitWidth > 0 && fileSet.LimitWidth != httpPostedImage.Width)
                        {
                            itemConfig.Success = false;
                            itemConfig.Message = string.Format("图片限宽度是:{0} 现宽度是:{1}", fileSet.LimitWidth, httpPostedImage.Width);
                            return;
                        }
                        if (fileSet.LimitHeight > 0 && fileSet.LimitHeight != httpPostedImage.Height)
                        {
                            itemConfig.Success = false;
                            itemConfig.Message = string.Format("图片限高度是:{0} 现高度是:{1}", fileSet.LimitHeight, httpPostedImage.Height);
                            return;
                        }
                        break;
                    }
            }
        }
        if (itemConfig.Success && fileSet.MaxSize > 0 && httpPostedImage.Size > fileSet.MaxSize * 1024)
        {
            itemConfig.Success = false;
            itemConfig.Message = string.Format("图片限尺寸是:{0}KB, 现尺寸是:{1}KB", fileSet.MaxSize, ((decimal)httpPostedImage.Size / 1024).MathRound(2));
        }
    }
    #endregion

    //#region 保存头像  private bool UpdateOriginalImg(int userId, string originalImg, int originalImgWidth, int originalImgHeight)
    ///// <summary>
    ///// 保存头像
    ///// </summary>
    ///// <param name="userId">作者id</param>
    ///// <param name="originalImg">头像原图</param>
    ///// <param name="originalImgWidth">头像宽度</param>
    ///// <param name="originalImgHeight">头像高度</param>
    ///// <returns></returns>
    //private bool UpdateOriginalImg(int userId, string originalImg, int originalImgWidth, int originalImgHeight)
    //{
    //    const string sql = @"UPDATE [Users] SET 
    //                                    uOriginalImg = @OriginalImg, uOriginalImgWidth = @OriginalImgWidth, uOriginalImgHeight = @OriginalImgHeight, 
    //                                    uImg = '', uCutWidth = 0, uCutHeight = 0, uCutX = 0, uCutY = 0                                         
    //                                WHERE UserId = @UserId";
    //    DbParameter[] param = {
    //                              DataBaseOperator.AutoBlogWrite.MakeInParam("@OriginalImg", DbType.String, 256, originalImg),
    //                              DataBaseOperator.AutoBlogWrite.MakeInParam("@OriginalImgWidth", DbType.Int32, 4, originalImgWidth),
    //                              DataBaseOperator.AutoBlogWrite.MakeInParam("@OriginalImgHeight", DbType.Int32, 4, originalImgHeight),
    //                              DataBaseOperator.AutoBlogWrite.MakeInParam("@UserId", DbType.Int32, 4, userId)
    //                          };
    //    return DataBaseOperator.AutoBlogWrite.ExecuteNonQuery(sql, CommandType.Text, param);
    //}
    //#endregion

    public bool IsReusable
    {
        get
        {
            return false;
        }
    }
}