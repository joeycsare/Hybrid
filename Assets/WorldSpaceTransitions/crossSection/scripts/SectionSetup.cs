/*
 The purpose of this script is to create cross-section material instances
 and - in case of capped sections - to scale the capped section prefabs to fit the model GameObject .
 */
using System.Collections.Generic;
using UnityEngine;
using System.IO;
using System.Reflection;
using MathGeoLib;
#if UNITY_EDITOR
using Threading;
using UnityEditor;
using UnityEngine.Rendering;
#endif

using System;

namespace WorldSpaceTransitions
{
    [System.Serializable]
    public enum BoundsOrientation { objectOriented, worldOriented };


    [ExecuteInEditMode]

    public class SectionSetup : MonoBehaviour
    {
        //[Tooltip("Reassign after geometry change")]
        [HideInInspector]
        public GameObject model;
        [SerializeField]
        [HideInInspector]
        private GameObject currentModel;
        [SerializeField]
        [HideInInspector]
        private Bounds bounds;
        [HideInInspector]
        public BoundsOrientation boundsMode = BoundsOrientation.worldOriented;
        [HideInInspector]
        public bool accurateBounds = false;
        [HideInInspector]
        public bool useMathGeo = true;
        [SerializeField]
        [HideInInspector]
        private bool previousAccurate;
        [SerializeField]
        [HideInInspector]
        private BoundsOrientation boundsModePrevious;
        private bool mainThreadUpdated = true;

        private Dictionary<Material, Material> materialsToreplace;

        public List<ShaderSubstitute> shaderSubstitutes;
        private bool recalculate = false;

        [System.Serializable]
        public struct ShaderSubstitute
        {
#if UNITY_EDITOR
            [ReadOnly]
#endif
            public Shader original;
            public Shader substitute;


            public ShaderSubstitute(Shader orig, Shader subst)
            {
                original = orig; substitute = subst;
            }
        }

#if UNITY_EDITOR
        public struct VertexData
        {
            public Vector3[] vertices;
            public Matrix4x4 matrix;
            public VertexData(Vector3[] vert, Matrix4x4 m)
            {
                vertices = vert;
                matrix = m;
            }
        }

        private readonly Queue<Action> _actionQueue = new Queue<Action>();
        public Queue<Action> ActionQueue
        {
            get
            {
                lock (Async.GetLock("ActionQueue"))
                {
                    return _actionQueue;
                }
            }
        }

        void OnValidate()
        {
            //Debug.Log("onvalidate");
            if (Application.isPlaying) return;
            Setup();
        }
#endif
        void Setup()
        {
            if (!mainThreadUpdated) return;
            ISizedSection csc = GetComponent<ISizedSection>();
            if (csc == null) return;
            if (model)
            {
                transform.rotation = (boundsMode == BoundsOrientation.objectOriented) ? transform.rotation = model.transform.rotation : Quaternion.identity;
                //Debug.Log((model != currentModel).ToString() + " | " + (accurateBounds != previousAccurate).ToString() + " | " + (boundsMode != boundsModePrevious).ToString());
                if (model != currentModel || accurateBounds != previousAccurate || boundsMode != boundsModePrevious || recalculate)
                {
                    Debug.Log((model != currentModel).ToString() + " | " + (accurateBounds != previousAccurate).ToString() + " | " + (boundsMode != boundsModePrevious).ToString());
                    bounds = GetBounds(model, boundsMode);

                    csc.Size(bounds, model, boundsMode);

                    if (accurateBounds) AccurateBounds(model, boundsMode);
                    if (!accurateBounds)
                    {
                        currentModel = model;
                        previousAccurate = accurateBounds;
                        boundsModePrevious = boundsMode;
                    }
                }
            }
            else
            {
                currentModel = null;
            }

            Matrix4x4 m = Matrix4x4.TRS(transform.position, transform.rotation, UnityEngine.Vector3.one);
            Shader.SetGlobalMatrix("_WorldToObjectMatrix", m.inverse);
            //hide the box when no model assigned
            foreach (Transform tr in transform)
            {
                //tr.gameObject.SetActive(model);
                try { tr.GetComponent<Renderer>().enabled = model; }
                catch { }
                try { tr.GetComponent<Collider>().enabled = model; }
                catch { }
            }
        }

#if UNITY_EDITOR
        public string CheckShaders()
        {
            //if (GraphicsSettings.renderPipelineAsset.name == "LightweightRenderPipelineAsset") return;
            List<Shader> shaderList = new List<Shader>();
            Renderer[] renderers = model.GetComponentsInChildren<Renderer>();
            foreach (Renderer r in renderers)
            {
                Material[] mats = r.sharedMaterials;
                foreach (Material m in mats)
                {
                    Shader sh = m.shader;
                    if (!shaderList.Contains(sh)) shaderList.Add(sh);
                }
            }

            Debug.Log(UnityEngine.Rendering.GraphicsSettings.renderPipelineAsset.GetType().Name);
            Debug.Log(UnityEngine.Rendering.GraphicsSettings.renderPipelineAsset.defaultShader.name);

            string renderPipelineAssetName = UnityEngine.Rendering.GraphicsSettings.renderPipelineAsset.GetType().Name;
            string shaderKeywordNeeded = "CLIP_PLANE";

            if (GetComponent<CappedSectionCorner>()) shaderKeywordNeeded = "CLIP_CORNER";
            if (GetComponent<CappedSectionBox>()) shaderKeywordNeeded = "CLIP_BOX";

            shaderSubstitutes.Clear();

            bool keywordSupport = true;

            string shaderInfo = "";

            foreach (Shader sh in shaderList)
            {
                bool isKeywordSupported = false;
                Shader substitute = getSubstitute(sh, renderPipelineAssetName, shaderKeywordNeeded, out isKeywordSupported);
                if (substitute != null)
                {
                    shaderSubstitutes.Add(new ShaderSubstitute(sh, substitute));
                    if (!isKeywordSupported) shaderInfo += "Add " + shaderKeywordNeeded + " keyword to " + substitute.name + " shader \n";
                }
                else
                {
                    if (!isKeywordSupported) shaderInfo += "Add " + shaderKeywordNeeded + " keyword to " + sh.name + " shader \n";
                }
                //keywordSupport = keywordSupport && isKeywordSupported;
            }
            if(shaderInfo == "")
            shaderInfo = "check o.k.; all shaders support " + shaderKeywordNeeded + " keyword";
            if (shaderSubstitutes.Count > 0) shaderInfo = "create and assign section materials using the below button";
            return shaderInfo;
        }
#endif

        public void CreateSectionMaterials()
        {
            Dictionary<Shader, Shader> shadersToreplace = new Dictionary<Shader, Shader>();
            foreach (ShaderSubstitute ssub in shaderSubstitutes)
            {
                shadersToreplace.Add(ssub.original, ssub.substitute);
            }
            materialsToreplace = new Dictionary<Material, Material>();
#if UNITY_EDITOR
            Undo.RegisterFullObjectHierarchyUndo(model, "crossSection material assign");
#endif
            Renderer[] renderers = model.GetComponentsInChildren<Renderer>();
            foreach (Renderer r in renderers)
            {
                Material[] mats = r.sharedMaterials;
                Material[] newMats = new Material[mats.Length];
                for (int i = 0; i < mats.Length; i++)
                {
                    Debug.Log(mats[i].name);
                    Shader sh = mats[i].shader;
                    if (shadersToreplace.ContainsKey(sh))
                    {
                        if (!materialsToreplace.ContainsKey(mats[i]))
                        {
                            Material newMaterial;
#if UNITY_EDITOR
                            string fpath = AssetDatabase.GetAssetPath(mats[i]);
                            string newName = mats[i].name + "_cs";
                            string dirname = Path.GetDirectoryName(fpath);
                            if (mats[i].name == "Default-Material") dirname = "Assets";
                            string newpath = Path.Combine(dirname, newName + ".mat");

                            newMaterial = (Material)AssetDatabase.LoadAssetAtPath(newpath, typeof(Material));
                            if (newMaterial == null)
                            {
#endif
                                newMaterial = new Material(mats[i]);
#if UNITY_EDITOR
                                newMaterial.name = newName;
                                AssetDatabase.CreateAsset(newMaterial, newpath);
                            }
#endif
                            newMaterial.shader = shadersToreplace[mats[i].shader];
                            materialsToreplace.Add(mats[i], newMaterial);
                        }
                        newMats[i] = materialsToreplace[mats[i]];
                    }
                    else
                    {
                        newMats[i] = mats[i];
                    }
                }
                r.materials = newMats;
            }
        }


        public void SetModel(GameObject _model)
        {
            if (Application.isPlaying) accurateBounds = false;
            model = _model;
            Setup();
        }
        public static Bounds GetBounds(GameObject go)
        {
            return GetBounds(go, BoundsOrientation.worldOriented);
        }

        public static Bounds GetBounds(GameObject go, BoundsOrientation boundsMode)
        {
            Debug.Log("getbounds");
            Quaternion quat = go.transform.rotation;//object axis AABB

            Bounds bounds = new Bounds();

            if (boundsMode == BoundsOrientation.objectOriented) go.transform.rotation = Quaternion.identity;

            //Renderer[] renderers = go.GetComponentsInChildren<Renderer>();
            MeshRenderer[] mrenderers = go.GetComponentsInChildren<MeshRenderer>();
            //Debug.Log(renderers.Length.ToString() + " | " + mrenderers.Length.ToString());
            if (mrenderers.Length > 0)
            {
                for (int i = 0; i < mrenderers.Length; i++)
                {
                    if (i == 0)
                    {
                        bounds = mrenderers[i].bounds;
                    }
                    else
                    {
                        bounds.Encapsulate(mrenderers[i].bounds);
                    }
                }
            }
            else
            {
#if UNITY_EDITOR
                EditorUtility.DisplayDialog("CrossSection message", "The object contains no meshRenderers!\n- please reassign", "Continue");
#endif
            }

            UnityEngine.Vector3 localCentre = go.transform.InverseTransformPoint(bounds.center);
            go.transform.rotation = quat;
            bounds.center = go.transform.TransformPoint(localCentre);

            return bounds;
        }

        void AccurateBounds(GameObject go, BoundsOrientation boundsMode)
        {

            MeshFilter[] meshes = go.GetComponentsInChildren<MeshFilter>();
            ISizedSection csc = GetComponent<ISizedSection>();
#if UNITY_EDITOR
            if (meshes.Length > 0)
            {
                /*int vertexCount = 0;
                for (int i = 0; i < meshes.Length; i++)
                {
                    Mesh ms = meshes[i].sharedMesh;
                    vertexCount += ms.vertexCount;
                }

                if (vertexCount > 10000 && EditorUtility.DisplayDialog("CrossSection message", "It can take a time\nto calculate the bounds box from " + vertexCount.ToString() + " vertices", "Skip this", "I can wait"))
                {
                    accurateBounds = false;
                    return;
                }*/
            }
            else
            {
                EditorUtility.DisplayDialog("CrossSection message", "The object contains no meshes!\n- please reassign", "Continue");
            }

            if (useMathGeo)
            {
                VertexData[] vertexData = new VertexData[meshes.Length];
                for (int i = 0; i < meshes.Length; i++)
                {
                    Mesh ms = meshes[i].sharedMesh;
                    vertexData[i] = new VertexData(ms.vertices, meshes[i].transform.localToWorldMatrix);
                }
                Vector3 v1 = (boundsMode == BoundsOrientation.objectOriented) ? go.transform.right : Vector3.right;
                Vector3 v2 = (boundsMode == BoundsOrientation.objectOriented) ? go.transform.up : Vector3.up;
                Vector3 v3 = (boundsMode == BoundsOrientation.objectOriented) ? go.transform.forward : Vector3.forward;

                Async.Run(() =>
                {
                    mainThreadUpdated = false;
                    Debug.Log("thread start");
                    bounds = OBB(vertexData, v1, v2, v3);
                }).ContinueInMainThread(() =>
                {
                    Debug.Log("back to main thread");
                    if (csc != null) csc.Size(bounds, go, boundsMode);
                    currentModel = model;
                    previousAccurate = accurateBounds;
                    boundsModePrevious = boundsMode;
                    enabled = false;
                    enabled = true;
                    recalculate = false;
                    //mainThreadUpdated = true;
                });

            }
            else
            {
#endif
                DateTime dt = DateTime.Now;
                Quaternion quat = go.transform.rotation;//objectOriented (OBB)
                if (boundsMode == BoundsOrientation.objectOriented) go.transform.rotation = Quaternion.identity;
                for (int i = 0; i < meshes.Length; i++)
                {
                    Mesh ms = meshes[i].sharedMesh;
                    int vc = ms.vertexCount;
                    Matrix4x4 matr = meshes[i].transform.localToWorldMatrix;
                    Debug.Log("ms.vertexCount " + vc.ToString());
                    for (int j = 0; j < vc; j++)
                    {
                        if (i == 0 && j == 0)
                        {
                            bounds = new Bounds(matr.MultiplyPoint3x4(ms.vertices[j]), UnityEngine.Vector3.zero);
                        }
                        else
                        {
                            bounds.Encapsulate(matr.MultiplyPoint3x4(ms.vertices[j]));
                        }
                        //if (j > 200) break;//for testing, otherwise it would take ages
                    }
#if UNITY_EDITOR
                }
#endif
                UnityEngine.Vector3 localCentre = go.transform.InverseTransformPoint(bounds.center);
                go.transform.rotation = quat;
                bounds.center = go.transform.TransformPoint(localCentre);
                if (csc != null) csc.Size(bounds, go, boundsMode);
                TimeSpan ts = dt - DateTime.Now;
                //Debug.Log(ts.ToString());
            }
        }

#if UNITY_EDITOR
        public static Bounds OBB(VertexData[] vdata, Vector3 v1, Vector3 v2, Vector3 v3)
        {
            DateTime dt = DateTime.Now;
            OrientedBoundingBox obb = new OrientedBoundingBox();
            Debug.Log("meshesCount " + vdata.Length.ToString());
            for (int i = 0; i < vdata.Length; i++)
            {
                VertexData ms = vdata[i];
                int vc = vdata[i].vertices.Length;
                Debug.Log("vertices " + vc.ToString());
                for (int j = 0; j < vc; j++)
                {
                    if (i == 0 && j == 0)
                    {
                        obb = new OrientedBoundingBox(vdata[i].matrix.MultiplyPoint3x4(vdata[i].vertices[j]), Vector3.zero, v1, v2, v3);
                    }
                    else
                    {
                        obb.Enclose(vdata[i].matrix.MultiplyPoint3x4(vdata[i].vertices[j]));
                    }
                }
            }

            TimeSpan ts = DateTime.Now - dt;
            //Debug.Log(ts.ToString());
            Bounds _bounds = new Bounds(obb.Center, 2 * obb.Extent);
            return _bounds;
        }
#endif
#if UNITY_EDITOR
        Shader getSubstitute(Shader shader, string pipelineAssetName, string keyword, out bool hasKeyword)
        {
            string familyName = "";
            string shaderName;
            string defaultshaderName;


            switch (pipelineAssetName)
            {
                case "UniversalRenderPipelineAsset":
                    if (shader.name.Contains("Shader Graphs"))
                    {
                        familyName = "CrossSectionGraphs/";
                    }
                    else
                    {
                        familyName = "CrossSectionURP/";
                    }
                    defaultshaderName = "CrossSectionURP/Lit";
                    break;
                case "HighDefinitionRenderPipelineAsset":
                    if (shader.name.Contains("Shader Graphs"))
                    {
                        familyName = "CrossSectionGraphs/";
                    }
                    else
                    {
                        familyName = "CrossSectionHDRP/";
                    }
                    defaultshaderName = "CrossSectionHDRP/Lit";
                    break;
                default:
                    if (keyword == "CLIP_BOX")
                    {
                        familyName = "CrossSection/Box/";
                    }
                    else
                    {
                        familyName = "CrossSection/";
                    }
                    defaultshaderName = "CrossSection/Standard";
                    break;
            }

            //methods to get list of global and local shader keywords are internal and private, only way to call them is via reflection
            var getKeywordsMethod = typeof(ShaderUtil).GetMethod("GetShaderGlobalKeywords", BindingFlags.Static | BindingFlags.NonPublic);
            List<string> keywordList;
            string[] keywords;

            //check the object shaders for keywords
            keywords = (string[])getKeywordsMethod.Invoke(null, new object[] { shader });
            keywordList = new List<string>(keywords);
            Debug.Log(keywordList[0]);
            hasKeyword = keywordList.Contains(keyword);
            //

            if (shader.name.Contains(familyName))
            {
                //keywords = (string[])getKeywordsMethod.Invoke(null, new object[] { shader });
                //keywordList = new List<string>(keywords);
                //Debug.Log(keywordList[0]);
                //hasKeyword = keywordList.Contains(keyword);
                return null;
            }

            shaderName = shader.name.Replace("Legacy Shaders/", "");
            string newName = familyName + shaderName;
            newName = newName.Replace("Transparent/VertexLit", "Transparent/Specular");
            if (newName.Contains("Transparent/VertexLit"))
            {
                newName = familyName + "Transparent/Specular";
            }
            else if (newName.Contains("Transparent"))
            {
                newName = familyName + "Transparent/Diffuse";
            }

            if (!Shader.Find(newName)) newName = defaultshaderName;
            Shader newShader = Shader.Find(newName);
            //keywords = (string[])getKeywordsMethod.Invoke(null, new object[] { newShader });
            //keywordList = new List<string>(keywords);
            //hasKeyword = keywordList.Contains(keyword);

            return newShader;
        }
#endif
        private void OnEnable()
        {
            //Mulithreading used in bound box calculations
            mainThreadUpdated = true;
            //boundsModePrevious = boundsMode;
        }
        void OnDrawGizmos()
        {
            // Your gizmo drawing thing goes here if required...
            // Update the main thread after the bound box calculations
#if UNITY_EDITOR
            // Ensure continuous Update calls.
            if (!Application.isPlaying && !mainThreadUpdated)
            {
                EditorApplication.QueuePlayerLoopUpdate();
                SceneView.RepaintAll();
            }
#endif
        }


        public void RecalculateBounds()
        {
            recalculate = true;
            Setup();
        }

    }
}
