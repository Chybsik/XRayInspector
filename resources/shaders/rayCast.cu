#version 430 core
#define M_PI 3.1415926535897932384626433832795

layout(std430, binding = 0) buffer ColorSSBO {
	int color[];
};

//in vec2 passTextureCoord;

uniform mat4 view;
uniform mat4 projection;

uniform int dataWidth;
uniform int dataHeight;
uniform int dataAmount;

uniform int screenWidth;
uniform int screenHeight;
uniform vec3 aabb1;
uniform vec3 aabb2;
//uniform float fov;
//uniform vec3 cameraPos;
//uniform vec3 cameraVec;
uniform int sampleResolution;

uniform float brightness;
uniform float treshold;

void Swap(inout float a, inout float b){
	float temp = a;
	a = b;
	b = temp;
}

vec3 Intersect(vec3 rayOrigin, vec3 rayDirection, vec3[2] axisAlighenBoundingBox, bool returnFirst){
	vec3[] result = vec3[2](vec3(0.0, 0.0, 0.0), vec3(0.0, 0.0, 0.0));
	
	//Box boundaries:
	float B0x = axisAlighenBoundingBox[0].x;
	float B1x = axisAlighenBoundingBox[1].x;
	float B0y = axisAlighenBoundingBox[0].y;
	float B1y = axisAlighenBoundingBox[1].y;
	float B0z = axisAlighenBoundingBox[0].z;
	float B1z = axisAlighenBoundingBox[1].z;
	
	//Ray assignment
	float Ox = rayOrigin.x;
	float Oy = rayOrigin.y;
	float Oz = rayOrigin.z;
	float Dx = rayDirection.x;
	float Dy = rayDirection.y;
	float Dz = rayDirection.z;
	
	//Calculation
	float t0x = (B0x - Ox) / Dx;
	float t1x = (B1x - Ox) / Dx;
	
	if (t0x > t1x) Swap(t0x, t1x);
	
	float t0y = (B0y - Oy) / Dy;
	float t1y = (B1y - Oy) / Dy;
	
	if (t0y > t1y) Swap(t0y, t1y);
	
	if (t0x > t1y || t0y > t1x)
		discard;
	
	if (t0y > t0x)
		t0x = t0y;
		
	if (t1y < t1x)
		t1x = t1y;
	
	float t0z = (B0z - Oz) / Dz;
	float t1z = (B1z - Oz) / Dz;
	
	if (t0z > t1z) Swap(t0z, t1z);
	
	if (t0x > t1z || t0z > t1x)
		discard;
		
	if (t0z > t0x)
		t0x = t0z;
		
	if (t1z < t1x)
		t1x = t1z;
	
	float tMin = t0x;
	float tMax = t1x;
	
	result[0] = vec3(rayDirection.x * tMin + rayOrigin.x, rayDirection.y * tMin + rayOrigin.y, rayDirection.z * tMin + rayOrigin.z);
	result[1] = vec3(rayDirection.x * tMax + rayOrigin.x, rayDirection.y * tMax + rayOrigin.y, rayDirection.z * tMax + rayOrigin.z);
	
	return returnFirst ? result[0] : result[1];
}

vec3 First(vec3 vOrig, vec3 vDir, vec3[2] aabb){
	//Coordinate of the first intersection
	return Intersect(vOrig, vDir, aabb, true);
}

vec3 Last(vec3 vOrig, vec3 vDir, vec3[2] aabb){
	//Coordinate of the last intersection
	return Intersect(vOrig, vDir, aabb, false);
}

vec3 Object(vec3 v){
	//To object(world) space
	vec4 result;
	result = inverse(projection * view) * vec4(v, 1.0);
	return result.xyz;
}

vec3 Image(vec3 v){
	//To image space
	vec4 result;
	result = projection * view * vec4(v, 1.0);
	return result.xyz;
}

vec3 Data(vec3 v) {
	//To data space
	vec3 result;

	vec3 resolution = vec3(dataWidth, dataHeight, dataAmount);
	vec3 offset = vec3(aabb2.x, aabb2.y, aabb2.z);
	
	result = (v + offset) * resolution;
	return result;
}

float Sample(vec3 c){
	float result;
	
	int x0, x1, y0, y1, z0, z1;
	
	float xd = mod(c.x, 1.0);
	float yd = mod(c.y, 1.0);
	float zd = mod(c.z, 1.0);
	
	if(xd == 0.0){
		x0 = int(c.x);
		x1 = x0;
	} else {
		x0 = int(c.x);
		x1 = int(c.x) + 1;
	}
	
	if(yd == 0.0){
		y0 = int(c.y);
		y1 = y0;
	} else {
		y0 = int(c.y);
		y1 = int(c.y) + 1;
	}
	
	if(zd == 0.0){
		z0 = int(c.z);
		z1 = z0;
	} else {
		z0 = int(c.z);
		z1 = int(c.z) + 1;
	}
	
	int c000 = color[x0 + y0 * dataWidth + z0 * dataWidth * dataHeight];
	int c001 = color[x0 + y0 * dataWidth + z1 * dataWidth * dataHeight];
	int c010 = color[x0 + y1 * dataWidth + z0 * dataWidth * dataHeight];
	int c011 = color[x0 + y1 * dataWidth + z1 * dataWidth * dataHeight];
	int c100 = color[x1 + y0 * dataWidth + z0 * dataWidth * dataHeight];
	int c101 = color[x1 + y0 * dataWidth + z1 * dataWidth * dataHeight];
	int c110 = color[x1 + y1 * dataWidth + z0 * dataWidth * dataHeight];
	int c111 = color[x1 + y1 * dataWidth + z1 * dataWidth * dataHeight];
	
	float c00 = c000 * (1 - xd) + c100 * xd;
	float c01 = c001 * (1 - xd) + c101 * xd;
	float c10 = c010 * (1 - xd) + c110 * xd;
	float c11 = c011 * (1 - xd) + c111 * xd;
	
	float c0 = c00 * (1 - yd) + c10 * yd;
	float c1 = c01 * (1 - yd) + c11 * yd;
	
	result = (c0 * (1 - zd) + c1 * zd);
	
	return result;
}

vec3 lerp(vec3 b, vec3 a, float x){
	return vec3(a.x * x + b.x * (1 - x), a.y * x + b.y * (1 - x), a.z * x + b.z * (1 - x));
}

vec3 colorRamp(float x){
	float s1 = 0.0;
	float s2 = 0.223;
	float s3 = 1.0;
	
	vec3 color1 = vec3(1.0, 0.786, 0.386);
	vec3 color2 = vec3(0.922, 0.0, 0.004);
	vec3 color3 = vec3(0.844, 0.782, 0.745);
	
	if(x < s2){
		x = x / s2;
		return lerp(color1, color2, x);
	} else{
		x = x - s2;
		float t = s3 - s2;
		x = x / t;
		return lerp(color2, color3, x);
	}
	
}

typedef struct
{
    float x, y, z;
} vec3;

extern "C" __global__ void render(float *fb) {
	int WIDTH = 1280;
	int HEIGHT = 720;
	int coordX = threadIdx.x + blockIdx.x * blockDim.x;
	int coordY = threadIdx.y + blockIdx.y * blockDim.y;
	
	if(coordX > WIDTH * HEIGHT) return;
	
	coordX /= WIDTH;
	coordY %= WIDTH;
	
	vec3[] aabb = vec3[2](aabb1, aabb2);

	vec3 origin = 

	float tx = (float(coordX) / float(WIDTH)) * 2.0 - 1.0;	//to NDC space
	float ty = (float(coordY) / float(HEIGHT)) * 2.0 - 1.0;
	vec3 rayOrigin = Object(vec3(tx, ty, 0.0));		///In object-space
	vec3 rayDirection = normalize(Object(vec3(tx, ty, -1.0)) - rayOrigin);
	
	vec3 modulation = rayDirection / sampleResolution;
	int correction = int(1.0 / screenWidth / modulation);	//voxel size divided by modulation = correction value
	if(correction == 0) correction = 1;
	
	vec3 C = vec3(1.0, 0.786, 0.386);
	
	vec3 target = vec3(1, 0, 0);
	float Alpha = 0;
	
	vec3 x1 = First(rayOrigin, rayDirection, aabb);
	vec3 x2 = Last(rayOrigin, rayDirection, aabb);
	
	float U1 = (Image(x1).z + 0.5) / 2;
	float U2 = (Image(x2).z + 0.5) / 2;
	
	vec3 x = x1;
	
	// Loop through all samples falling within data
	while (Image(x).z > Image(x2).z) {
		// If sample opacity > 0,
		// then resample color and composite into ray
		float a = Sample(Data(x));// Проба
		a = a / 255.0; // / correction;
		
		vec3 sampleColor = colorRamp(a);
		
		if(a > treshold){
			C = lerp(C, sampleColor, a);
			//C = lerp(C, target, a);
			//a = 1.0;
		}else{
			a =0.0;
		}
		Alpha += a;// * brightness;
		if(Alpha >= 1) break;
		
		x += modulation; // Прирощение координаты пробы
		
		//if (Alpha > 0){
		//	C = Sample(dataSet, x);
		//	c = c + C(1 - alpha);
		//	alpha = alpha + Alpha(U)(1 - alpha);
		//}
	}
	gl_FragColor = vec4(C, Alpha);
}
