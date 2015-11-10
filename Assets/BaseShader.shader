Shader "Custom/Base" {
	Properties
	{
		
		_AlbedoTex ("Albedo Texture", 2D) = "white" {}
		_NormalTex ("Normal Texture", 2D) = "white" {}
		_MetallicTex ("Metallic Texture", 2D) = "white" {}
		_SpecularTex ("Specular Texture", 2D) = "white" {}
		_RoughnessTex ("Roughness Texture", 2D) = "white" {}
		_EnvMap ("Env Texture", CUBE) = "white" {}
		_IrradianceMap ("Irradiance Texture", CUBE) = "white" {}
		
		_Roughness("Roughness", Float) = 0
		_Metallic("Metallic", Float) = 0
		
		_UserAlbedo("User Albedo", Color) = (0, 0, 0, 1.0)
		_UserSpecular("User Specular", Color) = (0, 0, 0, 1.0)
		
		_LightIntensity("Light Intensity", Float) = 0
		_ReflectionIntensity("Reflection Intensity", Float) = 0
		_AmbientLightIntensity("Ambient LightIntensity", Float) = 0
		
	}

    SubShader {
        Pass {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            //#pragma target 3.0
            //#pragma only_renderers gles3

            #include "UnityCG.cginc"
            #include "pbr.cginc"
            
            uniform float4 _LightColor0;
            sampler2D _AlbedoTex;
            sampler2D _NormalTex;
			sampler2D _MetallicTex;
			sampler2D _SpecularTex;
			
			sampler2D _RoughnessTex;
			samplerCUBE _EnvMap;
			samplerCUBE _IrradianceMap;
			
			float _Roughness;
			float _Metallic;
			
			float4 _UserAlbedo;
			float4 _UserSpecular;
			
			float _LightIntensity;
			float _ReflectionIntensity;
			float _AmbientLightIntensity;
			
            struct vertexInput {
                float4 vertex : POSITION;
                float4 texcoord0 : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct fragmentInput {
                float4 position : SV_POSITION;
                float4 texcoord0 : TEXCOORD0;
                float3 normal : NORMAL;
                float4 pos;
                float3 tangentWorld;  
         		float3 normalWorld;
         		float3 binormalWorld;
            };

            fragmentInput vert(vertexInput i)
            {
                fragmentInput o;
                
                o.pos = mul(_Object2World, i.vertex);
                //o.pos = float4(i.vertex.xyz, 1.0f);
//			    float4 worldPosition = float4(input.Position.xyz, 1.0f);
//			    float4 viewPosition = mul(worldPosition, View);
                o.position = mul (UNITY_MATRIX_MVP, i.vertex);
                o.texcoord0 = i.texcoord0;
                o.normal = i.normal;
                
                o.tangentWorld = normalize(mul(_Object2World, float4(i.tangent.xyz, 0.0)).xyz);
         		o.normalWorld = normalize(mul(float4(i.normal, 0.0), _World2Object).xyz);
         		o.binormalWorld = normalize(cross(o.normalWorld, o.tangentWorld) * i.tangent.w); // tangent.w is specific to Unity
                
                // Calculate tangent space to world space matrix using the world space tanget, binormal and normal as basis vector.
//			    output.tangentToWorld[0] = input.Tangent;
//			    output.tangentToWorld[1] = input.Binormal;
//			    output.tangentToWorld[2] = input.Normal;
                
                return o;
            }
            
            fixed4 frag(fragmentInput i) : SV_Target
            {
            	float4 lightPosition = _WorldSpaceLightPos0;
            	float3 lightColor = _LightColor0.rgb;
            	
            	float3 albedoColor = 0.0f;
            	
			    float3 normal = 0.0f;
#if defined(METALLIC) || defined(DISNEY_BRDF)
			    float metallic = 0.0f;
#elif defined(SPECULAR)
			    float3 specularColor = float3(0, 0, 0);
#endif

			    float roughness = 0.0f;

			    albedoColor = tex2D(_AlbedoTex, i.texcoord0).rgb;// * (1.0f - g_OverrideAlbedo);
    			
    			float4 enc_normal = tex2D(_NormalTex, i.texcoord0.xy);
    			
         		float3 localCoords = float3(2.0 * enc_normal.a - 1.0, 2.0 * enc_normal.g - 1.0, 0.0);
         		localCoords.z = sqrt(1.0 - dot(localCoords, localCoords));
         		// approximation without sqrt:  localCoords.z = 
         		// 1.0 - 0.5 * dot(localCoords, localCoords);
				
#if defined(METALLIC) || defined(DISNEY_BRDF)
    			metallic = tex2D(_MetallicTex, i.texcoord0).x;//  * (1.0f - g_OverrideMetallic);
#elif defined(SPECULAR)
    			specularColor = tex2D(_SpecularTex, i.texcoord0).x;// * (1.0f - g_OverrideSpecular);
#endif

    			roughness = tex2D(_RoughnessTex, i.texcoord0).x;//  * (1.0f - g_OverrideRoughness);
			    
//			    // Gamma correction.
    			//albedoColor = pow(albedoColor.rgb, 2.2f);

//    			// Compute screenspace normal.
    			//normal = 2.0f * normal - 1.0f;
    			//normal = normalize(normal);
    			float3x3 local2WorldTranspose = float3x3(i.tangentWorld, i.binormalWorld, i.normalWorld);
    			normal = normalize(mul(localCoords, local2WorldTranspose));// * (1.0f - g_OverrideNormal);
				
				//normal = normalize(i.normal);
				
    			roughness += _Roughness;// * g_OverrideRoughness;
    			
#if defined(METALLIC) || defined(DISNEY_BRDF)
			    metallic += _Metallic;// * g_OverrideMetallic;
#endif
    			albedoColor += _UserAlbedo;// * g_OverrideAlbedo;
    			normal += normalize(i.normal);// * g_OverrideNormal;

#ifdef USE_GLOSSINESS
    			roughness = 1.0f - roughness;
#endif

//#define POINT_LIGHT
//			    // Compute view direction.
			    float4 pos = i.pos / i.pos.w;
			    float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - pos);
			    
//#ifdef POINT_LIGHT
//    			float3 lightDir = normalize(lightPosition - pos);
//#else
    			float3 lightDir = normalize(lightPosition);
//#endif
//
#ifdef METALLIC
			    // Lerp with metallic value to find the good diffuse and specular.
			    float3 realAlbedo = albedoColor - albedoColor * metallic;
    			// 0.03 default specular value for dielectric.
    			float3 realSpecularColor = lerp(float3(0.03f,0.03f,0.03f), albedoColor, metallic);
#elif defined(SPECULAR)
    			float3 realAlbedo = albedoColor + _UserAlbedo;// * g_OverrideAlbedo;
    			float3 realSpecularColor = specularColor + _UserSpecular.xyz;// * g_OverrideSpecular;
#elif defined(DISNEY_BRDF)
    			float3 realAlbedo = albedoColor + _UserAlbedo;// * g_OverrideAlbedo;
    			float3 realSpecularColor = lerp(float3(0.03f,0.03f,0.03f), albedoColor, metallic); // TODO: Use disney specular color.
#endif // METALLIC

#ifndef DISNEY_BRDF
    			float3 light1 = ComputeLight( realAlbedo, realSpecularColor,  normal,  roughness,  lightPosition.xyz, lightColor, lightDir, viewDir);
#else
    			float3 spec = 0.0f.xxx;
    			float3 diffuse = 0.0f.xxx;
    			float3 light1 = DisneyBRDF(albedoColor, spec, normal, roughness, lightDir, viewDir, input.tangentToWorld[0], input.tangentToWorld[1], diffuse);
#endif
//
    			float lightDist = length(-lightPosition + pos);
//#ifdef POINT_LIGHT
//    			float attenuation = PI/(lightDist * lightDist);
//#else
    			float attenuation = 1.0f;//0.001f;
//#endif

				float mipIndex =  roughness * roughness * 8.0f;
			    float4 reflectVector = (reflect( -viewDir, normal), mipIndex);

			    float3 envColor = texCUBElod(_EnvMap, reflectVector);//, mipIndex);
			    float3 irradiance = texCUBE(_IrradianceMap, normal);
			    envColor = pow(envColor.rgb, 2.2f);

			    float3 envFresnel = Specular_F_Roughness(realSpecularColor, roughness * roughness, normal, viewDir);

#ifdef DISNEY_BRDF
    			attenuation *= 0.1f;
    			realAlbedo = saturate(diffuse);
#endif

    			return float4(attenuation * _LightIntensity * light1 + envFresnel*envColor * _ReflectionIntensity + realAlbedo * irradiance * _AmbientLightIntensity, 1.0f);
            
                //return float4(albedoColor, 1.0);
            }
            
            ENDCG
        }
    }
}