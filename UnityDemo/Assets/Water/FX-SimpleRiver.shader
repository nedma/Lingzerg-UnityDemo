Shader "Custom/FX/FX-SimpleRiver"
{
    Properties
    {
		[Header(Color)]
		_WaterColor("Water Color 浅水区颜色", Color) = (0,0.3411765,0.6235294,1)
		_DeepWaterColor("Deep Water Color 深水区颜色", Color) = (0,0.3411765,0.6235294,1)
		_DepthTransparency("Depth Transparency 水体透明度", Range(0.5,10)) = 1.5
		_Fade("Fade 颜色混合后乘数,控制颜色强度", Range(0.1,5)) = 1

		[Space(50)]
		[Header(Shore)]
		_ShoreFade("Shore Fade 岸边范围", Float) = 0.3
		_ShoreTransparency("Shore Transparency 岸边透明度", Float) = 0.04


		[Space(50)]
		[Header(Light)]
		_Specular("Specular 高光强度", Range(0, 10)) = 1
		_LightWrapping("Light Wrapping", Float) = 0
		_Gloss("Gloss 高光范围", Range(0, 1)) = 0.55

		[Space(50)]
		[Header(Small Waves)]
		[NoScaleOffset] _SmallWavesTexture("Small Waves Texture", 2D) = "bump" {}
		_SmallWavesTiling("Small Waves Tiling", Float) = 1.5
		_SmallWavesSpeed("Small Waves Speed", Float) = 60
		_SmallWaveRrefraction("Small Wave Rrefraction", Range(0, 3)) = 1

		[Space(50)]
		[Header(Medium Waves)]
		[NoScaleOffset]_MediumWavesTexture("Medium Waves Texture", 2D) = "bump" {}
		_MediumWavesTiling("Medium Waves Tiling", Float) = 3
		_MediumWavesSpeed("Medium Waves Speed", Float) = -80
		_MediumWaveRefraction("Medium Wave Refraction", Range(0, 3)) = 2

		[Space(50)]
		[Header(Large Waves)]
		[NoScaleOffset]_LargeWavesTexture("Large Waves Texture", 2D) = "bump" {}
		_LargeWavesTiling("Large Waves Tiling", Float) = 0.5
		_LargeWavesSpeed("Large Waves Speed", Float) = 60
		_LargeWaveRefraction("Large Wave Refraction", Range(0, 3)) = 2.5

		[Space(50)]
		[Header(TilingDistance)]
		_MediumTilingDistance("Medium Tiling Distance", Float) = 200
		_LongTilingDistance("Long Tiling Distance", Float) = 500
		_DistanceTilingFade("Distance Tiling Fade", Float) = 1



		[Space(50)]
		[Header(Reflections)]
		_ReflectionIntensity("Reflection Intensity ", Range(0, 1)) = 0.5
		[HideInInspector]_ReflectionTex("Reflection Tex", 2D) = "white" {}
		_RefractionDistance("Refraction Distance", Float) = 10
		_RefractionFalloff("Refraction Falloff 水面折射范围", Float) = 1

		[Space(50)]
		[Header(Foam)]
		
		//泡沫
		[NoScaleOffset]_FoamTexture("Foam Texture", 2D) = "white" {}
		_FoamTiling("Foam Tiling", Float) = 3
		_FoamBlend("Foam Blend", Float) = 0.15
		_FoamVisibility("Foam Visibility", Range(0, 1)) = 0.3
		_FoamIntensity("Foam Intensity", Float) = 10
		_FoamContrast("Foam Contrast", Range(0, 0.5)) = 0.25
		_FoamColor("Foam Color", Color) = (0.3823529,0.3879758,0.3879758,1)
		_FoamSpeed("Foam Speed", Float) = 120
		_FoamDistFalloff("Foam Dist. Falloff", Float) = 16
		_FoamDistFade("Foam Dist. Fade", Float) = 9.5/**/

		//岸边海浪
		[Space(50)]
		[Header(Surge)]
		[Toggle]
		_SurgeType("SurgeType",Float) = 1
		_Range("Range 海浪的范围", Range(0,5)) = 3
		_SurgeColor("Surge Color 海浪颜色", Color) = (0,0.3411765,0.6235294,1)
		_SurgeTex("Surge Tex 海浪流动贴图", 2D) = "Surge" {}
		_SurgeSpeed("SurgeSpeed 海浪速度", float) = -12.64 //海浪速度
		_SurgeRange("SurgeRange 海浪抖动范围(不是海浪范围)", float) = 0.3
		_SurgeDelta("SurgeDelta 对海浪波形压缩", float) = 2.43

		_NoiseRange("NoiseRange 噪声扰动半径", float) = 6.43
		_NoiseTex("Noise", 2D) = "white" {} //海浪躁波
    }
    SubShader
    {
	   Tags {
				"IgnoreProjector" = "True"
				"Queue" = "Transparent"
				"RenderType" = "Transparent"
			}

		GrabPass{ "_GrabTexture" }

        Pass
        {
			Tags {
				"LightMode" = "ForwardBase"
			}

			Blend SrcAlpha OneMinusSrcAlpha

			Cull Off
			ZWrite Off

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

			#include "UnityCG.cginc"
			#include "UnityPBSLighting.cginc"
			#include "UnityStandardBRDF.cginc"


			#pragma target 3.0

			uniform float4 _WaterColor;
			uniform float4 _DeepWaterColor;
			uniform float _DepthTransparency;
			uniform float _Fade;
			
			//自定义全局纹理, 深度和屏幕颜色
			//uniform sampler2D_float _LastDepthTexture;
			//uniform sampler2D_float _SceneColorTexture;
			uniform sampler2D _GrabTexture;
			uniform sampler2D_float _CameraDepthTexture;

			//反射相关的
			uniform sampler2D _ReflectionTex;
			uniform float4 _ReflectionTex_ST;

			uniform float _ReflectionIntensity;
			uniform fixed _EnableReflections;

			uniform float _RefractionDistance;
			uniform float _RefractionFalloff;

			//波浪相关参数

			uniform sampler2D _SmallWavesTexture;
			uniform sampler2D _MediumWavesTexture;
			uniform sampler2D _LargeWavesTexture;

			uniform float _SmallWaveRrefraction;
			uniform float _SmallWavesSpeed;
			uniform float _SmallWavesTiling;


			uniform float _MediumWavesTiling;
			uniform float _MediumWavesSpeed;
			uniform float _MediumWaveRefraction;

			uniform float _LargeWaveRefraction;
			uniform float _LargeWavesTiling;
			uniform float _LargeWavesSpeed;

			//波浪距离
			uniform float _MediumTilingDistance;
			uniform float _DistanceTilingFade;
			uniform float _LongTilingDistance;

			//光照
			uniform float _Specular;
			uniform float _LightWrapping;
			uniform float _Gloss;

			//岸边
			uniform float _ShoreFade;
			uniform float _ShoreTransparency;

			//泡沫相关参数
			uniform float _FoamBlend;
			uniform float4 _FoamColor;
			uniform float _FoamIntensity;
			uniform float _FoamContrast;
			uniform sampler2D _FoamTexture;
			uniform float _FoamSpeed;
			uniform float _FoamTiling;
			uniform float _FoamDistFalloff;
			uniform float _FoamDistFade;
			uniform float _FoamVisibility;

			//岸边海浪
			uniform float4 _SurgeColor;
			uniform sampler2D _SurgeTex;
			uniform float _SurgeSpeed;
			uniform float _SurgeRange;
			uniform float _Range;
			fixed _SurgeDelta;

			uniform sampler2D _NoiseTex;
			uniform float _NoiseRange;
			uniform float _SurgeType;

            struct VertexInput
            {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
				float2 texcoord0 : TEXCOORD0;
            };

            struct Interpolators
            {
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				float4 posWorld : TEXCOORD1;
				float3 normalDir : TEXCOORD2;
				float3 tangentDir : TEXCOORD3;
				float3 bitangentDir : TEXCOORD4;
				float4 screenPos : TEXCOORD5;
				float4 projPos : TEXCOORD6;
            };

			Interpolators vert (VertexInput v)
            {
				Interpolators i = (Interpolators)0;
				i.uv = v.texcoord0;
				i.normalDir = UnityObjectToWorldNormal(v.normal);
				i.tangentDir = normalize(mul(unity_ObjectToWorld, float4(v.tangent.xyz, 0.0)).xyz);
				i.bitangentDir = normalize(cross(i.normalDir, i.tangentDir) * v.tangent.w);

				i.posWorld = mul(unity_ObjectToWorld, v.vertex);

				i.pos = UnityObjectToClipPos(v.vertex);

				i.projPos = ComputeScreenPos(i.pos);
				COMPUTE_EYEDEPTH(i.projPos.z);
				i.screenPos = i.pos;
				
                return i;
            }

			float3 getWave(sampler2D tex, float3 objScale, Interpolators i,
				float tiling, float speed, float refraction,
				float _clampedDistance1, float _clampedDistance2) {

				//UV缩放设置
				float2 scale = objScale.rb*tiling;

				//根据时间和速度偏移UV
				float2 _smallWavesPanner = (i.uv + (float3((speed / scale), 0.0) * (_Time.r / 100.0)));

				float2 wavesUV = _smallWavesPanner * scale;

				//采样时, 根据时间偏移量和偏移缩放量采样
				float3 wavesTex = UnpackNormal(tex2D(tex, wavesUV));
				//第二次采样 uv 缩小20倍
				float3 wavesTex2 = UnpackNormal(tex2D(tex, wavesUV / 20.0));

				//类似之前的操作,采样uv被再次缩小,距离也同样
				float3 wavesTex3 = UnpackNormal(tex2D(tex, wavesUV / 60));

				return lerp(
					float3(0, 0, 1),
					lerp(lerp(wavesTex.rgb, wavesTex2.rgb, _clampedDistance1), wavesTex3.rgb, _clampedDistance2),
					lerp(lerp(refraction, refraction / 2.0, _clampedDistance1), (refraction / 8), _clampedDistance2));
			}

			float3 getFoam(Interpolators i, float3 _blendWaterColor,float3 objScale, float depthGap, float3 normalWaveLocal) {

				//根据波浪法线和屏幕坐标采样, *0.5+0.5是为了归一化
				float2 _remap = (i.screenPos.rg + normalWaveLocal.rg)*0.5 + 0.5;
				float4 _ReflectionTex_var = tex2D(_ReflectionTex, TRANSFORM_TEX(_remap, _ReflectionTex));

				float _rotator_ang = 1.5708;
				float _rotator_spd = 1.0;
				float _rotator_cos = cos(_rotator_spd*_rotator_ang);
				float _rotator_sin = sin(_rotator_spd*_rotator_ang);
				float2 _rotator_piv = float2(0.5, 0.5);

				//旋转UV, uv * 2D旋转矩阵
				float2 _rotator = (mul(i.uv - _rotator_piv, float2x2(_rotator_cos, -_rotator_sin, _rotator_sin, _rotator_cos)) + _rotator_piv);

				//泡沫贴图的Tiling和物体缩放相乘拿到UV缩放比例
				float2 _FoamDivision = objScale.rb*_FoamTiling;

				//UV根据时间偏移具体量
				float3 _foamUVSpeed = (float3(_FoamSpeed / _FoamDivision, 0.0)*(_Time.r / 100.0));

				////旋转后的UV + uv偏移量,拿到最终UV
				float2 _FoamAdd = (_rotator + _foamUVSpeed);

				////UV * 缩放乘数
				float2 _foamUV = (_FoamAdd*_FoamDivision);
				float4 _foamTex1 = tex2D(_FoamTexture, _foamUV);

				float2 _FoamAdd2 = (i.uv + _foamUVSpeed);
				float2 _foamUV2 = (_FoamAdd2*_FoamDivision);
				float4 _foamTex2 = tex2D(_FoamTexture, _foamUV2);

				float2 _foamUV3 = (_FoamAdd*objScale.rb*_FoamTiling / 3.0);
				float4 _foamTex3 = tex2D(_FoamTexture, _foamUV3);

				float2 maxUV = (_FoamAdd2*_foamUV3);
				float4 _foamTex4 = tex2D(_FoamTexture, maxUV);

				//根据距离混合泡沫纹理的几种不同的UV
				float3 blendFoamRGB = lerp((_foamTex1.rgb - _foamTex2.rgb), (_foamTex3.rgb - _foamTex4.rgb),
					saturate(pow((distance(i.posWorld.rgb, _WorldSpaceCameraPos) / 20), 3)));
				//去色
				float3 foamRGBGray = (dot(blendFoamRGB, float3(0.3, 0.59, 0.11)) - _FoamContrast) / (1.0 - 2 * _FoamContrast);

				//float depth = (saturate(depthGap / _FoamBlend) - 1.0);

				//根据深度混合颜色
				float3 foamRGB = foamRGBGray * _FoamColor.rgb *_FoamIntensity;// * lerp(1, depth, _FormType)

				float3 sqrtFoamRGB = (foamRGB*foamRGB);
				return lerp(_blendWaterColor, sqrtFoamRGB, _FoamVisibility);

			}

			//岸边拍打的海浪相关业务
			float3 getSurge(Interpolators i,float3 objScale, float depthGap)
			{
				//缩放UV
				float2  surgeUVScale = objScale.rb / 200;
				//噪波图
				fixed4 noiseColor = tex2D(_NoiseTex, i.uv*objScale.rb / 5);
				//第一个海浪
				fixed4 surgeColor = tex2D(_SurgeTex, float2(1 - min(_Range, depthGap) / _Range + _SurgeRange * sin(_Time.x*_SurgeSpeed + noiseColor.r*_NoiseRange), 1)*surgeUVScale);
				surgeColor.rgb *= (1 - (sin(_Time.x*_SurgeSpeed + noiseColor.r*_NoiseRange) + 1) / 2)*noiseColor.r;
				//第二个海浪
				fixed4 surgeColor2 = tex2D(_SurgeTex, float2(1 - min(_Range, depthGap) / _Range + _SurgeRange * sin(_Time.x*_SurgeSpeed + _SurgeDelta + noiseColor.r*_NoiseRange) + 0.5, 1)*surgeUVScale);
				surgeColor2.rgb *= (1 - (sin(_Time.x*_SurgeSpeed + _SurgeDelta + noiseColor.r*_NoiseRange) + 1) / 2)*noiseColor.r;

				//根据深度控制海浪范围
				half surgeWave = 1 - min(_Range, depthGap) / _Range;
				return (surgeColor.rgb + surgeColor2.rgb * _SurgeColor) * surgeWave;
			}
			

            fixed4 frag (Interpolators i) : SV_Target
            {
				//通过世界到模型空间转换矩阵,拿到基向量的变化,进而得知缩放信息
				//假如平面被缩放,我们要保证波浪不被跟着拉变形,所以需要这个信息
				float3 recipObjScale = float3(length(unity_WorldToObject[0].xyz), length(unity_WorldToObject[1].xyz), length(unity_WorldToObject[2].xyz));
				float3 objScale = 1.0 / recipObjScale;

#if UNITY_UV_STARTS_AT_TOP // OpenGL 和DX兼容设置
				float grabSign = -_ProjectionParams.x;
#else
				float grabSign = _ProjectionParams.x;
#endif

				i.normalDir = normalize(i.normalDir);
				i.screenPos = float4(i.screenPos.xy / i.screenPos.w, 0, 0);
				i.screenPos.y *= _ProjectionParams.x;

				//拿到切线变换,下面合并波浪法线要用
				float3x3 tangentTransform = float3x3(i.tangentDir, i.bitangentDir, i.normalDir);
				//视角方向,就是摄像机方向
				float3 viewDirection = normalize(_WorldSpaceCameraPos.xyz - i.posWorld.xyz);
				
				//算出距离相机的距离
				float _distance = distance(i.posWorld.rgb, _WorldSpaceCameraPos);
				//如果小于1 这个距离用平方缩小clamp距离
				float _clampedDistance1 = saturate(pow((_distance / _MediumTilingDistance), _DistanceTilingFade));
				float _clampedDistance2 = saturate(pow((_distance / _LongTilingDistance), _DistanceTilingFade));

				/**小波浪相关设置**/
				float3 _SmallWaveNormal = getWave(_SmallWavesTexture, objScale, i, _SmallWavesTiling, _SmallWavesSpeed, _SmallWaveRrefraction, _clampedDistance1, _clampedDistance2);
				/**中级波浪相关设置**/
				float3 _MediumWaveNormal = getWave(_MediumWavesTexture, objScale, i, _MediumWavesTiling, _MediumWavesSpeed, _MediumWaveRefraction, _clampedDistance1, _clampedDistance2);

				/**大波浪相关设置**/
				float3 _LargeWaveNormal = getWave(_LargeWavesTexture, objScale, i, _LargeWavesTiling, _LargeWavesSpeed, _LargeWaveRefraction, _clampedDistance1, _clampedDistance2);

				//合并波浪运算结果,偏转法线
				float3 normalWaveLocal = (_SmallWaveNormal + _MediumWaveNormal + _LargeWaveNormal);
				//乘以切线空间矩阵,拿到真正的法线
				float3 normalDirection = normalize(mul(normalWaveLocal, tangentTransform));

				float3 lightDirection = normalize(_WorldSpaceLightPos0.xyz);
				float3 lightColor = _LightColor0.rgb;
				float3 halfDirection = normalize(viewDirection + lightDirection);

				float attenuation = 1;
				float3 attenColor = attenuation * _LightColor0.xyz;

				// Gloss:
				float gloss = _Gloss;
				float specPow = exp2(gloss * 10.0 + 1.0);

				// 根据法线算高光Specular:
				float NdotL = saturate(dot(normalDirection, lightDirection));
				float3 specularColor = (_Specular*_LightColor0.rgb);
				float3 directSpecular = attenColor * pow(max(0, dot(halfDirection, normalDirection)), specPow)*specularColor;
				
				/**根据深度和坐标拿到当前的深度差**/
				//屏幕深度
				float sceneZ = max(0, LinearEyeDepth(UNITY_SAMPLE_DEPTH(tex2Dproj(_CameraDepthTexture, UNITY_PROJ_COORD(i.projPos)))) - _ProjectionParams.g);
				float partZ = max(0, i.projPos.z - _ProjectionParams.g);

				//深度差可以做很多事,比如岸边,根据深度颜色变化
				float depthGap = sceneZ - partZ;

				float deepMultiplier = pow(saturate(depthGap / _DepthTransparency), _ShoreFade)*saturate(depthGap / _ShoreTransparency);

				//偏移截屏UV, 实现类似折射的效果
				float2 sceneUVs = float2(1, grabSign) * i.screenPos.xy * 0.5 + 0.5
					+ lerp(
					((normalWaveLocal.rg*(_MediumWaveRefraction*0.02))*deepMultiplier),
						float2(0, 0), saturate(pow((distance(i.posWorld.rgb, _WorldSpaceCameraPos) / _RefractionDistance),
							_RefractionFalloff)));

				//截屏用在这里
				float4 sceneColor = tex2D(_GrabTexture, sceneUVs);
				
				//根据深度混合Deep color 和 water color
				float3 _blendWaterColor = saturate(
					_DeepWaterColor.rgb + sceneColor.rgb * saturate(_Fade - depthGap) * _WaterColor.rgb
				);
				//输出一下混合颜色
				//return float4(_blendWaterColor,1);

				/*泡沫*/
				float3 foamColor = getFoam(i, _blendWaterColor,objScale, depthGap, normalWaveLocal);

				/*海浪*/
				float3 surgeFinalColor = getSurge(i, objScale, depthGap);

				//输出一下海浪
				//return float4(surgeFinalColor, 1);

				//输出一下泡沫
				//return float4(foamColor,1);
				float foamDepht = 1 - (saturate(depthGap / _FoamBlend));
				//我在这里给了foamDepht一个0.5的乘数用来降低亮度,你可以去掉这个乘数试试效果
				//因为海浪和岸边的泡沫需要的亮度值是不同的,海浪需要的更高,为了统一就加了一个0.5
				float3 finalColor = directSpecular + _blendWaterColor+ lerp(foamDepht*0.5, surgeFinalColor, _SurgeType)* foamColor;
				fixed4 finalRGBA = fixed4(lerp(sceneColor.rgb, finalColor, deepMultiplier), 1);
				return finalRGBA;
            }
            ENDCG
        }
    }
}
