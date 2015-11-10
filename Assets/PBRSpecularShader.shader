Shader "PBR/PBRSpecularShader" {
	Properties
	{
		
		_AlbedoTex ("Albedo Texture", 2D) = "white" {}
		_UserAlbedo("User Albedo", Color) = (0, 0, 0, 1.0)
		
		_SpecularTex ("Specular Texture", 2D) = "white" {}
		_UserSpecular("User Specular", Color) = (0, 0, 0, 1.0)
		
		_Roughness("Roughness", Float) = 0
		_RoughnessTex ("Roughness Texture", 2D) = "white" {}
		
		_NormalTex ("Normal Texture", 2D) = "white" {}
		
		_EnvMap ("Env Texture", CUBE) = "white" {}
		_ReflectionIntensity("Reflection Intensity", Float) = 0
		
		_IrradianceMap ("Irradiance Texture", CUBE) = "white" {}
		_AmbientLightIntensity("Ambient LightIntensity", Float) = 0
		
	}
	
	CGINCLUDE
            
            //#pragma target 3.0
            //#pragma only_renderers gles3

            #include "UnityCG.cginc"
            #include "pbr.cginc"
            
            uniform float4 _LightColor0;
            sampler2D _AlbedoTex;
            sampler2D _NormalTex;
			sampler2D _SpecularTex;
			
			sampler2D _RoughnessTex;
			samplerCUBE _EnvMap;
			samplerCUBE _IrradianceMap;
			
			float _Roughness;

			float _ReflectionIntensity;
			float _AmbientLightIntensity;
			
			float4 _UserAlbedo;
			float4 _UserSpecular;
			
            struct vertexInput {
                float4 vertex : POSITION;
                float4 texcoord0 : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct fragmentInput {
                float4 position : SV_POSITION;
                float4 texcoord0 : TEXCOORD0;
                float4 pos : TEXCOORD1;
                float3 tangentWorld : TEXCOORD2;  
         		float3 normalWorld : TEXCOORD3;
         		float3 binormalWorld : TEXCOORD4;
            };

            fragmentInput vert(vertexInput i)
            {
                fragmentInput o;
                
                o.pos = mul(_Object2World, i.vertex);

                o.position = mul (UNITY_MATRIX_MVP, i.vertex);
                o.texcoord0 = i.texcoord0;
                
                o.tangentWorld = normalize(mul(_Object2World, float4(i.tangent.xyz, 0.0)).xyz);
         		o.normalWorld = normalize(mul(float4(i.normal, 0.0), _World2Object).xyz);
         		o.binormalWorld = normalize(cross(o.normalWorld, o.tangentWorld) * i.tangent.w); // tangent.w is specific to Unity
                
                return o;
            }
            
            fixed4 frag(fragmentInput i) : SV_Target
            {
            	float4 lightPosition = _WorldSpaceLightPos0;
            	float3 lightColor = _LightColor0.rgb;
            	
            	float3 albedoColor = 0.0f;
			    float3 n = 0.0f;
			    float3 specularColor = float3(0, 0, 0);
			    float roughness = 0.0f;

			    albedoColor = tex2D(_AlbedoTex, i.texcoord0).rgb;// * (1.0f - g_OverrideAlbedo);
    			
    			//float4 enc_normal = tex2D(_NormalTex, i.texcoord0.xy);
    			
         		//float3 localCoords = float3(2.0 * enc_normal.a - 1.0, 2.0 * enc_normal.g - 1.0, 0.0);
         		//localCoords.z = sqrt(1.0 - dot(localCoords, localCoords));
         		// approximation without sqrt:  localCoords.z = 1.0 - 0.5 * dot(localCoords, localCoords);
         		
         		float4 enc_normal = tex2D(_NormalTex, i.texcoord0.xy);
            	float3 localCoords =  2.0 * enc_normal.rgb - float3(1.0, 1.0, 1.0);
				
    			specularColor = tex2D(_SpecularTex, i.texcoord0).x;// * (1.0f - g_OverrideSpecular);
    			roughness = tex2D(_RoughnessTex, i.texcoord0).x;//  * (1.0f - g_OverrideRoughness);
			    
			    // Gamma correction.
    			albedoColor = pow(albedoColor.rgb, 2.2f);

    			float3x3 local2WorldTranspose = float3x3(i.tangentWorld, i.binormalWorld, i.normalWorld);
    			n = normalize(mul(localCoords, local2WorldTranspose));// * (1.0f - g_OverrideNormal);
				
    			roughness += _Roughness;// * g_OverrideRoughness;
    			albedoColor += _UserAlbedo;// * g_OverrideAlbedo;
    			//n += normalize(i.n);// * g_OverrideNormal;


//#define POINT_LIGHT
			    // Compute view direction.
			    //float4 pos = i.pos / i.pos.w;
			    float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.pos.xyz);
			    
//#ifdef POINT_LIGHT
//    			float3 lightDir = normalize(lightPosition - pos);
//#else
    			float3 lightDir = normalize(lightPosition);
//#endif

    			float3 realAlbedo = albedoColor + _UserAlbedo;// * g_OverrideAlbedo;
    			float3 realSpecularColor = specularColor + _UserSpecular.xyz;// * g_OverrideSpecular;

    			float3 light1 = ComputeLight( realAlbedo, realSpecularColor,  n,  roughness,  lightPosition.xyz, lightColor, lightDir, viewDir);

//#ifdef POINT_LIGHT
//				float lightDist = length(-lightPosition + pos);
//    			float attenuation = PI/(lightDist * lightDist);
//#else
    			float attenuation = 1.0f;//0.001f;
//#endif

				float mipIndex =  roughness * roughness * 8.0f;
			    float4 reflectVector = (reflect( -viewDir, n), mipIndex);

			    float3 envColor = texCUBElod(_EnvMap, reflectVector);//, mipIndex);
			    float3 irradiance = texCUBE(_IrradianceMap, n);
			    envColor = pow(envColor.rgb, 2.2f);

			    float3 envFresnel = Specular_F_Roughness(realSpecularColor, roughness * roughness, n, viewDir);

    			return float4(attenuation * lightColor.rgb * light1 + envFresnel*envColor * _ReflectionIntensity + realAlbedo * irradiance * _AmbientLightIntensity, 1.0f);
            }
            
            ENDCG


   SubShader {
      Pass {      
         Tags { "LightMode" = "ForwardBase" } 
            // pass for ambient light and first light source
 
         CGPROGRAM
            #pragma vertex vert  
            #pragma fragment frag  
            // the functions are defined in the CGINCLUDE part
         ENDCG
      }
   }
}