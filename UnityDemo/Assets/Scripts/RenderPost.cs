using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Profiling;
using UnityEngine.Rendering;
using UnityEngine.UI;

[ExecuteInEditMode]
[RequireComponent(typeof(Camera))]
public class RenderPost : MonoBehaviour
{
    private Camera _Camera;
    public bool isCustomDepth = true;

    private void Awake()
    {
        _Camera = GetComponent<Camera>();
        //_Camera.depthTextureMode = DepthTextureMode.Depth;
        //PrintImage.Create();
        if (isCustomDepth)
        {
            CustomDepth();
        } else
        {
            _Camera.depthTextureMode = DepthTextureMode.Depth;
        }
        
        //if (PrintImage != null && SourceImage != null)
        //{
        //    BlurTexture(SourceImage, _Iterator, _BlurSize, _DownSample, PrintImage);
        //}
    }

    private void OnPreRender()
    {
        if (_Camera != null)
        {
            //设置各种全局矩阵
            Matrix4x4 viewMat = _Camera.worldToCameraMatrix;
            Matrix4x4 projMat = GL.GetGPUProjectionMatrix(_Camera.projectionMatrix, false);
            Matrix4x4 viewProjMat = (projMat * viewMat);
            Shader.SetGlobalMatrix("_ViewProjInv", viewProjMat.inverse);

            //_width, _height;
            Shader.SetGlobalFloat("_ScreenWidth", _Camera.pixelWidth);
            Shader.SetGlobalFloat("_ScreenHight", _Camera.pixelHeight);

            if (isCustomDepth)
            {
                //获取深度
                if (colorRT != null && depthRT != null)
                {

                    depthRT.DiscardContents();
                    colorRT.DiscardContents();
                    depthTex.DiscardContents();
                    colorTex.DiscardContents();

                    _Camera.SetTargetBuffers(colorRT.colorBuffer, depthRT.depthBuffer);
                }
            }
        }
    }

    private void Update()
    {

        //设置全局纹理
        Shader.SetGlobalTexture("_SceneColorTexture", colorTex);
        Shader.SetGlobalTexture("_LastDepthTexture", depthTex);
    }

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (isCustomDepth && colorRT != null)
        {
            //把颜色写回相机目标纹理
            if (getBloomMaterial != null && isBloom)
            {
                PostBloom(colorRT);
            }

            Graphics.Blit(colorRT, destination);
        } else
        {

            if (getBloomMaterial != null && isBloom)
            {
                PostBloom(source);
            }
            Graphics.Blit(source, destination);
        }
    }

    //private void OnPostRender()
    //{
    //    if (isCustomDepth)
    //    {
    //        //把颜色写回相机目标纹理
    //        if (colorRT != null)
    //        {
    //            if (getBloomMaterial != null && isBloom)
    //            {
    //                PostBloom(colorRT);
    //            }

    //            Graphics.Blit(colorRT, (RenderTexture) null);
    //            // Graphics.Blit(colorRT, _Camera.targetTexture);
    //        }
    //    }

        
    //}


    #region RenderTexture Depth

    private CommandBuffer _cbDepth = null;
    private CommandBuffer _cbColor = null;

    private RenderTexture depthRT;
    private RenderTexture colorRT;

    private RenderTexture depthTex;
    private RenderTexture colorTex;

    private void CustomDepth()
    {
        //绑定到相机的纹理,要是用延迟渲染 Gbuffer里自带这些信息, 或者SRP里的MRT都可以
        depthRT = new RenderTexture(_Camera.pixelWidth, _Camera.pixelHeight, 24, RenderTextureFormat.Depth);
        depthRT.name = "MainDepthBuffer";

        colorRT = new RenderTexture(_Camera.pixelWidth, _Camera.pixelHeight, 24, RenderTextureFormat.RGB111110Float);
        colorRT.name = "MainColorBuffer";

        //最后用下面两个纹理获取具体数据
        depthTex = new RenderTexture(_Camera.pixelWidth, _Camera.pixelHeight, 24, RenderTextureFormat.RFloat);
        depthTex.name = "SceneDepthTex";

        colorTex = new RenderTexture(_Camera.pixelWidth, _Camera.pixelHeight, 24, RenderTextureFormat.ARGBFloat);
        colorTex.name = "SceneColorTex";


        //绑定深度CB
        _cbDepth = new CommandBuffer();
        _cbDepth.name = "CommandBuffer_DepthBuffer";
        _cbDepth.Blit(depthRT.depthBuffer, depthTex.colorBuffer);
        _Camera.AddCommandBuffer(CameraEvent.AfterForwardOpaque, _cbDepth);

        //绑定颜色CB
        _cbColor = new CommandBuffer();
        _cbColor.name = "CommandBuffer_ColorBuffer";
        _cbColor.Blit(colorRT.colorBuffer, colorTex.colorBuffer);
        _Camera.AddCommandBuffer(CameraEvent.AfterForwardOpaque, _cbColor);
    }

    #endregion

    #region Blur RenderTexture

    //临时测试变量
    [Header("Blur")]
    public Shader boxFilterBlurShader;
    private Material boxFilterMaterial = null;

    public Material getBoxFilterMaterial
    {
        get
        {
            boxFilterMaterial = CheckShaderAndCreateMaterial(boxFilterBlurShader, boxFilterMaterial);
            return boxFilterMaterial;
        }
    }

    [Range(1, 16)]
    public int _BlurIterations = 1;

    const int BoxDownPass = 0;
    const int BoxUpPass = 1;

    public void BlurTexture(Texture source, int iterator, int blurSize, int downSample, RenderTexture PrintImage)
    {
        RenderTexture[] textures = new RenderTexture[16];

        int width = source.width / downSample;
        int height = source.height / downSample;
        RenderTextureFormat format = PrintImage.format;
        PrintImage.DiscardContents();
        RenderTexture currentDestination = textures[0] =
            RenderTexture.GetTemporary(width, height, 0, format);
        currentDestination.DiscardContents();

        Graphics.Blit(source, currentDestination, getBoxFilterMaterial, BoxDownPass);
        RenderTexture currentSource = currentDestination;

        int i = 1;
        for (; i < iterator; i++)
        {
            width /= 2;
            height /= 2;
            if (height < 2)
            {
                break;
            }
            currentDestination = textures[i] =
                RenderTexture.GetTemporary(width, height, 0, format);
            Graphics.Blit(currentSource, currentDestination, getBoxFilterMaterial, BoxDownPass);
            currentSource.DiscardContents();
            currentSource = currentDestination;
        }

        for (i -= 2; i >= 0; i--)
        {
            currentDestination = textures[i];
            textures[i] = null;
            Graphics.Blit(currentSource, currentDestination, getBoxFilterMaterial, BoxUpPass);
            RenderTexture.ReleaseTemporary(currentSource);
            currentSource = currentDestination;
        }
        currentDestination.DiscardContents();
        Graphics.Blit(currentDestination, PrintImage, getBoxFilterMaterial, BoxUpPass);
        RenderTexture.ReleaseTemporary(currentDestination);
    }


    #endregion

    #region Post-Bloom

    [Header("Post - Bloom")]
    public bool isBloom;

    [Range(0, 10)]
    public float bloomIntensity = 1;

    [Range(1, 16)]
    public int bloomIterations = 4;

    [Range(0, 10)]
    public float bloomThreshold = 1;

    [Range(0, 1)]
    public float bloomSoftThreshold = 0.5f;

    public Shader bloomShader;

    private Material bloomMaterial = null;
    public Material getBloomMaterial
    {
        get
        {
            bloomMaterial = CheckShaderAndCreateMaterial(bloomShader, bloomMaterial);
            return bloomMaterial;
        }
    }

    const int BoxDownPrefilterPass = 0;
    const int ApplyBloomPass = 3;
    const int DebugBloomPass = 4;


    RenderTexture[] textures = new RenderTexture[16];

    void PostBloom(RenderTexture source)
    {
        float knee = bloomThreshold * bloomSoftThreshold;
        Vector4 filter;
        filter.x = bloomThreshold;
        filter.y = filter.x - knee;
        filter.z = 2f * knee;
        filter.w = 0.25f / (knee + 0.00001f);
        getBloomMaterial.SetVector("_Filter", filter);
        getBloomMaterial.SetFloat("_Intensity", Mathf.GammaToLinearSpace(bloomIntensity));

        int width = source.width;
        int height = source.height;
        RenderTextureFormat format = source.format;

        RenderTexture currentDestination = textures[0] = RenderTexture.GetTemporary(width, height, 0, format);
        currentDestination.DiscardContents();
        Graphics.Blit(source, currentDestination, getBloomMaterial, BoxDownPrefilterPass);
        RenderTexture currentSource = currentDestination;

        int i = 1;

        for (; i < bloomIterations; i++)
        {
            width /= 2;
            height /= 2;
            if (height < 2)
            {
                break;
            }
            currentDestination = textures[i] = RenderTexture.GetTemporary(width, height, 0, format);
            currentSource.DiscardContents();
            Graphics.Blit(currentSource, currentDestination, getBloomMaterial, BoxDownPass);

            currentSource = currentDestination;
        }

        for (i -= 2; i >= 0; i--)
        {
            currentDestination = textures[i];
            textures[i] = null;
            Graphics.Blit(currentSource, currentDestination, getBloomMaterial, BoxUpPass);
            RenderTexture.ReleaseTemporary(currentSource);
            currentSource = currentDestination;
        }
        getBloomMaterial.SetTexture("_SourceTex", source);

        RenderTexture destination = RenderTexture.GetTemporary(width, height, 0, format);
        destination.DiscardContents();
        Graphics.Blit(currentSource, destination, getBloomMaterial, ApplyBloomPass);

        Graphics.Blit(destination, source);

        RenderTexture.ReleaseTemporary(destination);
        RenderTexture.ReleaseTemporary(currentSource);

    }

    #endregion

    #region util

    // Called when need to create the material used by this effect
    protected Material CheckShaderAndCreateMaterial(Shader shader, Material material)
    {
        if (shader == null)
        {
            return null;
        }

        if (shader.isSupported && material && material.shader == shader)
            return material;

        if (!shader.isSupported)
        {
            return null;
        }
        else
        {
            material = new Material(shader);
            material.hideFlags = HideFlags.DontSave;
            if (material)
                return material;
            else
                return null;
        }
    }

    #endregion
}
