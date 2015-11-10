#ifndef PBR_INCLUDED
#define PBR_INCLUDED

#define PI 3.14159265359f

#define SPECULAR 1
//#define METALLIC 0
//#define DISNEY_BRDF 0
#define NDF_GGX 1
#define FRESNEL_SCHLICK 1
#define GEOMETRIC_SMITH_SCHLICK_GGX 1

//NDF_BLINNPHONG
//NDF_BECKMANN
//NDF_GGX
//
//FRESNEL_SCHLICK
//FRESNEL_NONE
//FRESNEL_COOKTORRANCE
//
//GEOMETRIC_IMPLICIT
//GEOMETRIC_NEUMANN
//GEOMETRIC_COOKTORRANCE
//GEOMETRIC_KELEMEN
//GEOMETRIC_SMITH_BECKMANN
//GEOMETRIC_SMITH_GGX
//GEOMETRIC_SMITH_SCHLICK_GGX

////

float3 Diffuse(float3 pAlbedo)
{
    return pAlbedo/PI;
}

//-------------------------- Disney BRDF helpers functions --------------------------------------------
float sqr(float x)
{
    return x*x;
}

float GTR2_aniso(float NdH, float HdX, float HdY, float ax, float ay)
{
    return 1.0f / (PI * ax*ay * sqr(sqr(HdX/ax) + sqr(HdY/ay) + NdH*NdH));
}

float smithG_GGX(float NdV, float alphaG)
{
    float a = alphaG*alphaG;
    float b = NdV*NdV;
    return 1.0f / (NdV + sqrt(a + b - a*b));
}

float GTR1(float NdH, float a)
{
    if (a >= 1.0f)
    {
        return 1.0f / PI;
    }

    float a2 = a*a;
    float t = 1.0f + (a2 - 1.0f) * NdH * NdH;
    return (a2 - 1.0f) / (PI*log(a2)*t);
}

//-------------------------- Normal distribution functions --------------------------------------------
float NormalDistribution_GGX(float a, float NdH)
{
	// h == m in papers (microfacet normal)
    // Isotropic ggx.
    float a2 = a*a;
    float NdH2 = NdH * NdH;

    float denominator = NdH2 * (a2 - 1.0f) + 1.0f;
    denominator *= denominator;
    denominator *= PI;

    return a2 / denominator;
}

float NormalDistribution_BlinnPhong(float a, float NdH)
{
    return (1 / (PI * a * a)) * pow(NdH, 2 / (a * a) - 2);
}

float NormalDistribution_Beckmann(float a, float NdH)
{
    float a2 = a * a;
    float NdH2 = NdH * NdH;

    return (1.0f/(PI * a2 * NdH2 * NdH2 + 0.001)) * exp( (NdH2 - 1.0f) / ( a2 * NdH2));
}

//-------------------------- Geometric shadowing -------------------------------------------
float Geometric_Implicit(float a, float NdV, float NdL)
{
    return NdL * NdV;
}

float Geometric_Neumann(float a, float NdV, float NdL)
{
    return (NdL * NdV) / max(NdL, NdV);
}

float Geometric_CookTorrance(float a, float NdV, float NdL, float NdH, float VdH)
{
    return min(1.0f, min((2.0f * NdH * NdV)/VdH, (2.0f * NdH * NdL)/ VdH));
}

float Geometric_Kelemen(float a, float NdV, float NdL, float LdV)
{
    return (2 * NdL * NdV) / (1 + LdV);
}

float Geometric_Beckman(float a, float dotValue)
{
    float c = dotValue / ( a * sqrt(1.0f - dotValue * dotValue));

    if ( c >= 1.6f )
    {
        return 1.0f;
    }
    else
    {
        float c2 = c * c;
        return (3.535f * c + 2.181f * c2) / ( 1 + 2.276f * c + 2.577f * c2);
    }
}

float Geometric_Smith_Beckmann(float a, float NdV, float NdL)
{
    return Geometric_Beckman(a, NdV) * Geometric_Beckman(a, NdL);
}

float Geometric_GGX(float a, float dotValue)
{
    float a2 = a * a;
    return (2.0f * dotValue) / (dotValue + sqrt(a2 + ((1.0f - a2) * (dotValue * dotValue))));
}

float Geometric_Smith_GGX(float a, float NdV, float NdL)
{
    return Geometric_GGX(a, NdV) * Geometric_GGX(a, NdL);
}

float Geometric_Smith_Schlick_GGX(float a, float NdV, float NdL)
{
        // Smith schlick-GGX.
    float k = a * 0.5f;
    float GV = NdV / (NdV * (1 - k) + k);
    float GL = NdL / (NdL * (1 - k) + k);

    return GV * GL;
}

//-------------------------- Fresnel -------------------------------------
float3 Fresnel_None(float3 specularColor)
{
    return specularColor;
}

// Used by Disney BRDF.
float Fresnel_Schlick(float u)
{
    float m = saturate( 1.0f - u);
    float m2 = m*m;
    return m2*m2*m;
}

float3 Fresnel_Schlick(float3 specularColor, float3 h, float3 v)
{
    return (specularColor + (1.0f - specularColor) * pow((1.0f - saturate(dot(v, h))), 5));
}

float3 Fresnel_CookTorrance(float3 specularColor, float3 h, float3 v)
{
    float3 n = (1.0f + sqrt(specularColor)) / (1.0f - sqrt(specularColor));
    float c = saturate(dot(v, h));
    float3 g = sqrt(n * n + c * c - 1.0f);

    float3 part1 = (g - c)/(g + c);
    float3 part2 = ((g + c) * c - 1.0f)/((g - c) * c + 1.0f);

    return max(0.0f.xxx, 0.5f * part1 * part1 * ( 1 + part2 * part2));
}

float Specular_D(float a, float NdH)
{
#ifdef NDF_BLINNPHONG
    return NormalDistribution_BlinnPhong(a, NdH);
#else
#ifdef NDF_BECKMANN
    return NormalDistribution_Beckmann(a, NdH);
#else
#ifdef NDF_GGX
    return NormalDistribution_GGX(a, NdH);
#endif
#endif
#endif
}

float3 Specular_F(float3 specularColor, float3 h, float3 v)
{
#ifdef FRESNEL_NONE
    return Fresnel_None(specularColor);
#else
#ifdef FRESNEL_SCHLICK
    return Fresnel_Schlick(specularColor, h, v);
#else
#ifdef FRESNEL_COOKTORRANCE
    return Fresnel_CookTorrance(specularColor, h, v);
#endif
#endif
#endif
}

float3 Specular_F_Roughness(float3 specularColor, float a, float3 h, float3 v)
{
#ifdef FRESNEL_SCHLICK
    // Sclick using roughness to attenuate fresnel.
    return (specularColor + (max(1.0f-a, specularColor) - specularColor) * pow((1 - saturate(dot(v, h))), 5));
#else
#ifdef FRESNEL_NONE
    return Fresnel_None(specularColor);
#else
#ifdef FRESNEL_COOKTORRANCE
    return Fresnel_CookTorrance(specularColor, h, v);
#endif
#endif
#endif
}

float Specular_G(float a, float NdV, float NdL, float NdH, float VdH, float LdV)
{
#ifdef GEOMETRIC_IMPLICIT
    return Geometric_Implicit(a, NdV, NdL);
#else

#ifdef GEOMETRIC_NEUMANN
    return Geometric_Neumann(a, NdV, NdL);
#else

#ifdef GEOMETRIC_COOKTORRANCE
    return Geometric_CookTorrance(a, NdV, NdL, NdH, VdH);
#else

#ifdef GEOMETRIC_KELEMEN
    return Geometric_Kelemen(a, NdV, NdL, LdV);
#else

#ifdef GEOMETRIC_SMITH_BECKMANN
    return Geometric_Smith_Beckmann(a, NdV, NdL);
#else

#ifdef GEOMETRIC_SMITH_GGX
    return Geometric_Smith_GGX(a, NdV, NdL);
#else

#ifdef GEOMETRIC_SMITH_SCHLICK_GGX
    return Geometric_Smith_Schlick_GGX(a, NdV, NdL);
#endif
#endif
#endif
#endif
#endif
#endif
#endif
}

float3 Specular(float3 specularColor, float3 h, float3 v, float3 l, float a, float NdL, float NdV, float NdH, float VdH, float LdV)
{
    return ((Specular_D(a, NdH) * Specular_G(a, NdV, NdL, NdH, VdH, LdV)) * Specular_F(specularColor, v, h) ) / (4.0f * NdL * NdV + 0.0001f);
}

float3 ComputeLight(float3 albedoColor,float3 specularColor, float3 normal, float roughness, float3 lightPosition, float3 lightColor, float3 lightDir, float3 viewDir)
{
    // Compute some useful values.
    float NdL = saturate(dot(normal, lightDir));
    float NdV = saturate(dot(normal, viewDir));
    //float NdV = abs(dot(normal, viewDir));
    float3 h = normalize(lightDir + viewDir);
    float NdH = saturate(dot(normal, h));
    float VdH = saturate(dot(viewDir, h));
    float LdV = saturate(dot(lightDir, viewDir));
    float a = max(0.001f, roughness * roughness);

    float3 cDiff = Diffuse(albedoColor);
    
    float3 sD = Specular_D(a, NdH);
    float3 sG = Specular_G(a, NdV, NdL, NdH, VdH, LdV);
    float3 sF = Specular_F(specularColor, viewDir, h);
        
    float3 cSpec = (sD * sG *  sF) / (4.0f * NdL * NdV + 0.0001f);
    //Specular(specularColor, h, viewDir, lightDir, a, NdL, NdV, NdH, VdH, LdV);
    
    //return lightColor * NdL * (cDiff * (1.0f - cSpec) + cSpec);
    // Correction term according to 2013 Siggraph paper "rad"
    return lightColor * NdL * (cDiff * (1.0f - sF) + cSpec);
}

#ifdef DISNEY_BRDF
// From Disney's BRDF explorer: https://github.com/wdas/brdf
float3 DisneyBRDF(float3 baseColor,out float3 specularColor, float3 normal, float roughness, float3 lightDir, float3 viewDir, float3 X, float3 Y, out float3 diffuse)
{
    // Compute some useful values.
    float NdL = saturate(dot(normal, lightDir));
    float NdV = saturate(dot(normal, viewDir));

    float3 h = normalize(lightDir + viewDir);
    float NdH = saturate(dot(normal, h));
    float VdH = saturate(dot(viewDir, h));
    float LdV = saturate(dot(lightDir, viewDir));
    float LdH = saturate(dot(lightDir, h));
    float a = max(0.001f, roughness * roughness);

    float luminance = 0.3f * baseColor.x + 0.6f * baseColor.y + 0.1f * baseColor.z;

    float3 tint = luminance > 0.0f ? baseColor/luminance : 1.0f.xxx; // Normalize luminance to isolate hue+sat.
    specularColor = lerp(g_Specular * 0.08f * lerp(1.0f.xxx, tint, g_SpecularTint), baseColor, g_Metallic);
    float3 CSheen = lerp(1.0f.xxx, tint, g_SheenTint);

    // Diffuse fresnel - go from 1 at normal incidence to .5 at grazing
    // and mix in diffuse retro-reflection based on roughness
    float FL = Fresnel_Schlick(NdL);
    float FV = Fresnel_Schlick(NdV);
    float Fd90 = 0.5f + 2.0f * LdH * LdH * a;
    float Fd = lerp(1.0f, Fd90, FL) * lerp(1.0f, Fd90, FV);

    // Based on Hanrahan-Krueger brdf approximation of isotropic bssrdf
    // 1.25 scale is used to (roughly) preserve albedo
    // Fss90 used to "flatten" retroreflection based on roughness
    float Fss90 = LdH * LdH * a;
    float Fss = lerp(1.0f, Fss90, FL) * lerp(1.0f, Fss90, FV);
    float ss = 1.25f * (Fss * (1.0f / (NdL + NdV + 0.0001f) - 0.5f) + 0.5f);

    // Specular
    float aspect = sqrt(1.0f - g_Anisotropic*0.9f);
    float ax = max(0.001f, sqr(a)/aspect);
    float ay = max(0.001f, sqr(a)*aspect);
    float Ds = GTR2_aniso(NdH, dot(h, X), dot(h, Y), ax, ay);
    float FH = Fresnel_Schlick(LdH);
    float3 Fs = lerp(specularColor, 1.0f.xxx, FH);
    float roughg = sqr(a*0.5f+0.5f);
    float Gs = smithG_GGX(NdL, roughg) * smithG_GGX(NdV, roughg);

    // Sheen
    float3 Fsheen = FH * g_Sheen * CSheen;

    // Clearcoat (ior = 1.5 -> F0 = 0.04)
    float Dr = GTR1(NdH, lerp(0.1f, 0.001f, g_ClearcoatGloss));
    float Fr = lerp(0.04f, 1.0f, FH);
    float Gr = smithG_GGX(NdL, 0.25f) * smithG_GGX(NdV, 0.25f);
    diffuse = ((1.0f/PI) * lerp(Fd, ss, g_Subsurface) * baseColor + Fsheen) * (1.0f - g_Metallic);
    return (diffuse + Gs*Fs*Ds + 0.25f*g_Clearcoat*Gr*Fr*Dr)*NdL;
}
#endif

#endif //PBR_INCLUDED