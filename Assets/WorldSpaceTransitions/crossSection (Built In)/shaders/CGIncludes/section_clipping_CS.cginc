//section_clipping_CS.cginc

#ifndef SECTION_CLIPPING_INCLUDED
// Upgrade NOTE: excluded shader from DX11, OpenGL ES 2.0 because it uses unsized arrays
//#pragma exclude_renderers d3d11 gles
#define SECTION_CLIPPING_INCLUDED

//Plane clipping definitions

#if CLIP_PLANE || CLIP_PIE || CLIP_SPHERE || CLIP_TUBES || CLIP_TUBE || CLIP_BOX || CLIP_CORNER || CLIP_SPHERES || CLIP_PRISM || CLIP_PRISMS || CLIP_CYLINDER || CLIP_CYLINDERS || CLIP_TETRA || CLIP_TETRAS || CLIP_CONE || CLIP_CONES || CLIP_ELLIPSOID || CLIP_ELLIPSOIDS || CLIP_CUBOID || CLIP_CUBOIDS
	//SECTION_CLIPPING_ENABLED will be defined.
	//This makes it easier to check if this feature is available or not.
	#define SECTION_CLIPPING_ENABLED 1


#if CLIP_PLANE || CLIP_PIE || CLIP_SPHERE || CLIP_TUBE 
	uniform float3 _SectionPoint;

	#if CLIP_PLANE || CLIP_PIE
	uniform float _SectionOffset = 0;
	uniform float3 _SectionPlane;
	#endif

	#if CLIP_PIE
	uniform float3 _SectionPlane2;
	#endif
	#if CLIP_SPHERE || CLIP_TUBE 
	uniform float _Radius = 0;
	#endif
#endif

#if CLIP_PLANE || CLIP_CUBOID || CLIP_SPHERE || CLIP_SPHERES || CLIP_BOX || CLIP_TUBES || CLIP_TUBE 
	fixed _inverse;
#endif

#if CLIP_TUBE
	uniform float4 _AxisDir;
#endif

#if CLIP_TUBES
	uniform float4 _AxisDirs[64];
#endif
#if CLIP_TUBES || CLIP_SPHERES
	uniform float4 _centerPoints[64];
	uniform float _Radiuses[64];
	uniform int _centerCount = 0;
#endif

#if CLIP_PRISMS || CLIP_CYLINDERS || CLIP_TETRAS || CLIP_CONES || CLIP_ELLIPSOIDS || CLIP_CUBOIDS || CLIP_BOXES
	uniform float4x4 _WorldToObjectMatrixes[64];
	uniform float4  _SectionScales[64]; // if prisms have individual scales
	uniform int _primCount = 0;
	int _primCountTruncated = 0;
#endif

#if CLIP_BOX ||  CLIP_CORNER ||  CLIP_PRISM || CLIP_CYLINDER || CLIP_TETRA || CLIP_CONE || CLIP_ELLIPSOID || CLIP_CUBOID
	uniform float4x4 _WorldToObjectMatrix;
#if CLIP_BOX ||  CLIP_PRISM || CLIP_CYLINDER || CLIP_TETRA || CLIP_CONE || CLIP_ELLIPSOID || CLIP_CUBOID
	uniform float4 _SectionScale;
#endif
#endif
	
#if CLIP_BOX ||  CLIP_CORNER || CLIP_CUBOID || CLIP_PRISM || CLIP_CYLINDER || CLIP_PRISMS || CLIP_CYLINDERS || CLIP_TETRA || CLIP_TETRAS || CLIP_CONE || CLIP_ELLIPSOID || CLIP_CONES || CLIP_ELLIPSOIDS || CLIP_CUBOID || CLIP_CUBOIDS
#if CLIP_BOX
	// boxIntersect - ray intersects the box
	// txx - world-to-box transformation
	// ro is the ray origin in world space
	// rd is the ray direction in world space
	// txx is the world-to-box transformation
	// rad is the half-length of the box
	bool boxIntersect(in float3 ro, in float3 rd, in float4x4 txx, in float3 rad)
	{
		float3 rdd = (mul(txx, float4(rd, 0.0))).xyz;
		float3 roo = (mul(txx, float4(ro, 1.0))).xyz;

		float3 m = 1.0 / rdd;
		float3 n = m * roo;
		float3 k = abs(m)*rad;

		float3 t1 = -n - k;
		float3 t2 = -n + k;

		float tN = max(max(t1.x, t1.y), t1.z);
		float tF = min(min(t2.x, t2.y), t2.z);
		if (tN > tF || tF < 0.0) return false;
		return true;
	}
#endif
#if CLIP_BOX || CLIP_CUBOID || CLIP_CUBOIDS
	// clipBox - point po is outside box
	// txx - world-to-box transformation
	// po - point in world space
	// poo - point in box object space
	bool clipBox(in float3 po, in float4x4 txx, in float3 rad)
	{
		float3 poo = (mul(txx, float4(po, 1.0))).xyz;
		bool clip = (abs(poo.x) - rad.x) > 0 || (abs(poo.y) - rad.y) > 0 || (abs(poo.z) - rad.z) > 0;
#if CLIP_CUBOID || CLIP_CUBOIDS
		clip = !clip;
#endif
		return clip;
	}
#endif

#if CLIP_CYLINDER || CLIP_CYLINDERS
	// txx - world-to-cylinder transformation
	// po - point in world space
	// poo - point in cylinder object space
	bool clipCylinderInside(in float3 po, in float4x4 txx, in float3 rad)
	{
		float3 poo = (mul(txx, float4(po, 1.0))).xyz;
		bool clip = (abs(poo.z) - rad.z) < 0; // top and bottom – same as for box
		clip = clip && ((poo.x / rad.x)*(poo.x / rad.x) + (poo.y / rad.y)*(poo.y / rad.y) < 1); //eliptical cylinder
		return clip;
	}
#endif

#if CLIP_PRISM || CLIP_PRISMS
	// txx - world-to-prism transformation
	// po - point in world space
	// poo - point in prism object space
	bool clipPrismInside(in float3 po, in float4x4 txx, in float3 rad)
	{
		float3 poo = (mul(txx, float4(po, 1.0))).xyz;
		bool clip = (abs(poo.y) - rad.y) < 0; // top and bottom – same as for box
		clip = clip && (poo.z > 0.8660254*(-2 * poo.x*rad.z / rad.x - rad.z)); //– a leading edge
		clip = clip && (poo.z > 0.8660254*(2 * poo.x*rad.z / rad.x - rad.z));// – second leading edge
		clip = clip && (poo.z < rad.z);// – back side
		return clip;
	}
#endif

#if CLIP_TETRA || CLIP_TETRAS
	float det3x3_Philipp(in float3 b, in float3 c, in float3 d)
	{
		return b.x * c.y * d.z + c.x * d.y * b.z + d.x * b.y * c.z - d.x * c.y * b.z - c.x * b.y * d.z - b.x * d.y * c.z;
	}

	bool clipTetraInside(in float3 po, in float4x4 txx, in float3 rad)
	{
		float3 poo = (mul(txx, float4(po, 1.0))).xyz;

		float3 a = 2 * rad * float3(0.5773503, 0, 0.2041241) - poo;
		float3 b = 2 * rad * float3(-0.2886751, 0.5, 0.2041241) - poo;
		float3 c = 2 * rad * float3(-0.2886751, -0.5, 0.2041241) - poo;
		float3 d = 2 * rad * float3(0, 0, -0.6123724) - poo;

		float detA = det3x3_Philipp(b, c, d);
		float detB = det3x3_Philipp(a, c, d);
		float detC = det3x3_Philipp(a, b, d);
		float detD = det3x3_Philipp(a, b, c);
		bool ret0 = detA > 0.0 && detB < 0.0 && detC > 0.0 && detD < 0.0;
		bool ret1 = detA < 0.0 && detB > 0.0 && detC < 0.0 && detD > 0.0;
		return ret0 || ret1;
	}
#endif

#if CLIP_CONE || CLIP_CONES
	// txx - world-to-cylinder transformation
	// po - point in world space
	// poo - point in cylinder object space
	bool clipConeInside(in float3 po, in float4x4 txx, in float3 rad)
	{
		float3 poo = (mul(txx, float4(po, 1.0))).xyz;
		bool clip = (abs(poo.z) - rad.z) < 0; // top and bottom – same as for box
		clip = clip && ((poo.x / rad.x)*(poo.x / rad.x) + (poo.y / rad.y)*(poo.y / rad.y) < (1 + poo.z / rad.z)*(1 + poo.z / rad.z) / 4); //eliptical cone
		return clip;
	}
#endif

#if CLIP_ELLIPSOID || CLIP_ELLIPSOIDS
	// txx - world-to-cylinder transformation
	// po - point in world space
	// poo - point in cylinder object space
	bool clipSphereInside(in float3 po, in float4x4 txx, in float3 rad)
	{
		float3 poo = (mul(txx, float4(po, 1.0))).xyz;
		bool clip = ((poo.x / rad.x)*(poo.x / rad.x) + (poo.y / rad.y)*(poo.y / rad.y) + (poo.z / rad.z)*(poo.z / rad.z) < 1); //ellipsoide
		return clip;
	}
#endif

#if CLIP_CORNER
	bool clipCorner(in float3 po, in float4x4 txx)
	{
		float3 poo = (mul(txx, float4(po, 1.0))).xyz;
		return (poo.x > 0 && poo.y > 0 && poo.z > 0);
	}
#endif
#endif
#if CLIP_PIE
	static const float vcrossY = cross(_SectionPlane, _SectionPlane2).y;
	static const float dotCam = dot(_WorldSpaceCameraPos - _SectionPoint, _SectionPlane);
	static const float dotCam2 = dot(_WorldSpaceCameraPos - _SectionPoint, _SectionPlane2);
#endif

	//discard drawing of a point in the world if it is behind any one of the planes.
	bool ClipBool(in float3 posWorld) {
		bool _clip = false;
#if CLIP_PIE
		if (vcrossY >= 0) {//<180
			_clip = _clip || (-dot((posWorld - _SectionPoint), _SectionPlane) < 0);
			_clip = _clip || (-dot((posWorld - _SectionPoint), _SectionPlane2) < 0);
		}
		if (vcrossY < 0) {//>180
			_clip = _clip || ((_SectionOffset - dot((posWorld - _SectionPoint), _SectionPlane) < 0) && (-dot((posWorld - _SectionPoint), _SectionPlane2) < 0));
			//_clip = _clip || (posWorld.y > _ycut);
		}
#endif
#if CLIP_PLANE
		_clip = _clip || (_SectionOffset - dot((posWorld - _SectionPoint), _SectionPlane)*(1 - 2 * _inverse) < 0);
#endif
#if CLIP_SPHERE
		_clip = _clip || ((1 - 2 * _inverse)*(dot((posWorld - _SectionPoint), (posWorld - _SectionPoint)) - _Radius * _Radius) < 0);// discard; //_inverse = 1 : negative to clip the outside of the sphere
#endif
#if CLIP_SPHERE_OUT
		_clip = ((dot((posWorld - _SectionPoint), (posWorld - _SectionPoint)) - _Radius * _Radius) > 0);
#endif
#if CLIP_TUBE
		bool _clipTube = ((dot(posWorld - _SectionPoint - _AxisDir * dot(_AxisDir, posWorld - _SectionPoint), posWorld - _SectionPoint - _AxisDir * dot(_AxisDir, posWorld - _SectionPoint)) - _Radius * _Radius) < 0);
		if (_inverse == 0)
		{
			_clip = _clip || _clipTube;
		}
		else
		{
			_clip = _clip || !_clipTube;
		}
#endif
#if CLIP_TUBES
		bool _clipTubes = false;
		int _centerCountTruncated = min(_centerCount, 64);
		for (int i = 0; i < _centerCountTruncated; i++)
		{
			_clipTubes = _clipTubes || ((dot(posWorld - _centerPoints[i] - _AxisDirs[i] * dot(_AxisDirs[i], posWorld - _centerPoints[i]), posWorld - _centerPoints[i] - _AxisDirs[i] * dot(_AxisDirs[i], posWorld - _centerPoints[i])) - _Radiuses[i] * _Radiuses[i]) < 0);
		}

		if (_inverse == 0)
		{
			_clip = _clip || _clipTubes;
		}
		else
		{
			_clip = _clip || !_clipTubes;
		}
#endif
#if CLIP_SPHERES
		bool _clipSpheres = false;
		int _centerCountTruncated = min(_centerCount, 64);
		for (int i = 0; i < _centerCountTruncated; i++)
		{
			_clipSpheres = _clipSpheres || ((dot(posWorld - _centerPoints[i], posWorld - _centerPoints[i]) - _Radiuses[i] * _Radiuses[i]) < 0);
		}

		if (_inverse == 0)
		{
			_clip = _clip || _clipSpheres;
		}
		else
		{
			_clip = _clip || !_clipSpheres;
		}
#endif
#if CLIP_BOX || CLIP_CUBOID
		bool _clipBox = clipBox(posWorld, _WorldToObjectMatrix, 0.5*_SectionScale.xyz);
		_clip = _clip || _clipBox;
#endif
#if CLIP_PRISM
		_clip = clipPrismInside(posWorld, _WorldToObjectMatrix, 0.5*_SectionScale.xyz);
#endif
#if CLIP_CYLINDER
		_clip = clipCylinderInside(posWorld, _WorldToObjectMatrix, 0.5*_SectionScale.xyz);
#endif
#if CLIP_TETRA
		_clip = clipTetraInside(posWorld, _WorldToObjectMatrix, 0.5*_SectionScale.xyz);
#endif
#if CLIP_CONE
		_clip = clipConeInside(posWorld, _WorldToObjectMatrix, 0.5*_SectionScale.xyz);
#endif
#if CLIP_ELLIPSOID
		_clip = clipSphereInside(posWorld, _WorldToObjectMatrix, 0.5*_SectionScale.xyz);
#endif
#if CLIP_PRISMS
		bool _clipPrisms = false;
		_primCountTruncated = min(_primCount, 64);//let's assume 64 as maximum prism count expected
		for (int i = 0; i < _primCountTruncated; i++)
		{
			_clipPrisms = _clipPrisms || clipPrismInside(posWorld, _WorldToObjectMatrixes[i], 0.5*_SectionScales[i].xyz);
		}
		_clip = _clip || _clipPrisms;
#endif
#if CLIP_CYLINDERS
		bool _clipCyls = false;
		_primCountTruncated = min(_primCount, 64);//let's assume 64 as maximum prism count expected
		for (int i = 0; i < _primCountTruncated; i++)
		{
			_clipCyls = _clipCyls || clipCylinderInside(posWorld, _WorldToObjectMatrixes[i], 0.5*_SectionScales[i].xyz);
		}
		_clip = _clip || _clipCyls;
#endif
#if CLIP_TETRAS
		bool _clipTetras = false;
		_primCountTruncated = min(_primCount, 64);//let's assume 64 as maximum prism count expected
		for (int i = 0; i < _primCountTruncated; i++)
		{
			_clipTetras = _clipTetras || clipTetraInside(posWorld, _WorldToObjectMatrixes[i], 0.5*_SectionScales[i].xyz);
		}
		_clip = _clip || _clipTetras;
#endif
#if CLIP_CONES
		bool _clipCones = false;
		_primCountTruncated = min(_primCount, 64);//let's assume 64 as maximum prism count expected
		for (int i = 0; i < _primCountTruncated; i++)
		{
			_clipCones = _clipCones || clipConeInside(posWorld, _WorldToObjectMatrixes[i], 0.5*_SectionScales[i].xyz);
		}
		_clip = _clip || _clipCones;
#endif
#if CLIP_ELLIPSOIDS
		bool _clipELLIPSOIDs = false;
		_primCountTruncated = min(_primCount, 64);//let's assume 64 as maximum prism count expected
		for (int i = 0; i < _primCountTruncated; i++)
		{
			_clipELLIPSOIDs = _clipELLIPSOIDs || clipSphereInside(posWorld, _WorldToObjectMatrixes[i], 0.5*_SectionScales[i].xyz);
		}
		_clip = _clip || _clipELLIPSOIDs;
#endif
#if CLIP_BOXES || CLIP_CUBOIDS
		bool _clipBoxes = false;
		int _boxCountTruncated = min(_primCount, 64);//let's assume 64 as maximum box count expected
		for (int i = 0; i < _boxCountTruncated; i++)
		{
			_clipBoxes = _clipBoxes || clipBox(posWorld, _WorldToObjectMatrixes[i], 0.5*_SectionScales[i].xyz);
		}
		_clip = _clip || _clipBoxes;
		//_clip = _clip || !_clipBoxes;
#endif
#if CLIP_CORNER
		_clip = clipCorner(posWorld, _WorldToObjectMatrix);
#endif
		return _clip;
	}

	void Clip(float3 posWorld)
	{
		if (ClipBool(posWorld)) discard;
	}


	#if CLIP_BOX ||CLIP_PIE
	void Intersect(float3 posWorld) {
		bool _clip = false;
#if CLIP_BOX
		_clip = !boxIntersect(posWorld, normalize(_WorldSpaceCameraPos - posWorld), _WorldToObjectMatrix, 0.5*_SectionScale);
		if (_inverse == 1) _clip = !_clip;
		if (_clip) discard;
#endif
#if CLIP_PIE
		float dotProd = dot(posWorld - _SectionPoint, _SectionPlane);
		float dotProd2 = dot(posWorld - _SectionPoint, _SectionPlane2);
		if (vcrossY >= 0)
		{
			_clip = (dotProd > 0 && dotCam > 0) || (dotProd2 > 0 && dotCam2 > 0);
		}
		else
		{
			_clip = dotProd > 0 && dotProd2 > 0;
		}
		//_clip = _clip || (posWorld.y > _ycut);
#endif
		if (_clip) discard;

	}


	#define SECTION_INTERSECT(posWorld) Intersect(posWorld); //preprocessor macro that will produce an empty block if no clipping planes are used.
	#endif


//preprocessor macro that will produce an empty block if no clipping planes are used.
#define SECTION_CLIP(posWorld) Clip(posWorld);
#define OUT_MASKED(posWorld) ClipBool(posWorld);
    
#else
//empty definition
#define SECTION_CLIP(s)
#define SECTION_INTERSECT(s) //empty definition
//#define PLANE_FADE(s)
#endif


#endif // SECTION_CLIPPING_INCLUDED