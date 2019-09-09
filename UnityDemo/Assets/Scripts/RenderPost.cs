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
        if (isCustomDepth)
        {
            //把颜色写回相机目标纹理
            if (colorRT != null)
            {
                if (getBloomMaterial != null && isBloom)
                {
                    PostBloom(colorRT);
                }

                //Graphics.Blit(colorRT, (RenderTexture)null);
                Graphics.Blit(colorRT, destination);
            }
        } else
        {
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


    #region Post-Bloom

    [Header("Post - Bloom")]
    public bool isBloom;

    [Range(0, 4)]
    public int iterations = 3;

    // Blur spread for each iteration - larger value means more blur
    [Range(0.2f, 3.0f)]
    public float blurSpread = 0.6f;

    [Range(1, 8)]
    public int bloomDownSample = 2;

    [Range(0.0f, 4.0f)]
    public float luminanceThreshold = 0.6f;

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

    void PostBloom(RenderTexture src)
    {
        getBloomMaterial.SetFloat("_LuminanceThreshold", luminanceThreshold);

        int rtW = src.width / bloomDownSample;
        int rtH = src.height / bloomDownSample;

        RenderTexture buffer0 = RenderTexture.GetTemporary(rtW, rtH, 0);
        buffer0.filterMode = FilterMode.Bilinear;

        Graphics.Blit(src, buffer0, getBloomMaterial, 0);

        for (int i = 0; i < iterations; i++)
        {
            getBloomMaterial.SetFloat("_BlurSize", 1.0f + i * blurSpread);

            RenderTexture buffer1 = RenderTexture.GetTemporary(rtW, rtH, 0);

            // Render the vertical pass
            Graphics.Blit(buffer0, buffer1, getBloomMaterial, 1);

            RenderTexture.ReleaseTemporary(buffer0);
            buffer0 = buffer1;
            buffer1 = RenderTexture.GetTemporary(rtW, rtH, 0);

            // Render the horizontal pass
            Graphics.Blit(buffer0, buffer1, getBloomMaterial, 2);

            RenderTexture.ReleaseTemporary(buffer0);
            buffer0 = buffer1;
        }
        getBloomMaterial.SetTexture("_Bloom", buffer0);

        RenderTexture dest = RenderTexture.GetTemporary(src.width, src.height, 0);
        dest.filterMode = FilterMode.Bilinear;

        Graphics.Blit(src, dest, getBloomMaterial, 3);
        Graphics.Blit(dest,src);
        RenderTexture.ReleaseTemporary(buffer0);
        RenderTexture.ReleaseTemporary(dest);
       
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
