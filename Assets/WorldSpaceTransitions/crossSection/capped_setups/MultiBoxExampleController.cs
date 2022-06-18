using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace WorldSpaceTransitions
{
    public class MultiBoxExampleController : MonoBehaviour
    {
        public bool debug_ray_origin = false;
        private CappedSectionBox[] multiBoxes = new CappedSectionBox[0];
        Matrix4x4[] mxs;
        Vector4[] boxScales;

        // Start is called before the first frame update
        void Start()
        {
            multiBoxes = FindObjectsOfType<CappedSectionBox>();
            foreach (CappedSectionBox csbx in multiBoxes) csbx.enabled = false;
      
            mxs = new Matrix4x4[multiBoxes.Length];
            boxScales = new Vector4[multiBoxes.Length];
            //Debug.Log(multiBoxes.Length.ToString());
            Shader.SetGlobalInt("_boxCount", multiBoxes.Length);
            if (debug_ray_origin) Shader.SetGlobalVector("_RayOrigin", Camera.main.transform.position);
            SetSection();
        }

        // Update is called once per frame
        void LateUpdate()
        {
            Ray ray = Camera.main.ScreenPointToRay(Input.mousePosition);
            RaycastHit[] hits;
            List<RaycastHit> boxHits = new List<RaycastHit>();

            hits = Physics.RaycastAll(ray);
            CappedSectionBox csb;
            foreach (RaycastHit rh in hits)
            {
                csb = rh.transform.gameObject.GetComponentInParent<CappedSectionBox>();
                if (csb)
                {
                    boxHits.Add(rh);
                };
            }
            //Debug.Log("hits " + hits.Length.ToString() + " | boxHits " + boxHits.Count.ToString());
            boxHits.Sort((x, y) => x.distance.CompareTo(y.distance));//if you need descending sort, swap x and y on the right-hand side of the arrow =>.
            if (boxHits.Count > 0)
            {
                RaycastHit closesttHit = boxHits[0];
                csb = closesttHit.transform.gameObject.GetComponentInParent<CappedSectionBox>();
                foreach (CappedSectionBox csbx in multiBoxes)
                {
                    if (csbx == csb)
                    {
                        csbx.enabled = true;
                    }
                    else
                    {
                        csbx.StopAllCoroutines();
                        csbx.enabled = false;
                    }
                }
            }
            if (debug_ray_origin) Shader.SetGlobalVector("_RayOrigin", Camera.main.transform.position);
            SetSection();
        }

        void OnDisable()
        {
            Shader.DisableKeyword("CLIP_BOXES");
            Shader.EnableKeyword("CLIP_NONE");
            Shader.DisableKeyword("RAY_ORIGIN");
        }

        void OnEnable()
        {
            Shader.EnableKeyword("CLIP_BOXES");
            Shader.DisableKeyword("CLIP_NONE");
            Shader.SetGlobalInt("_boxCount", multiBoxes.Length);
            if (debug_ray_origin) Shader.EnableKeyword("RAY_ORIGIN");
            //SetSection();
        }

        void OnApplicationQuit()
        {
            Shader.DisableKeyword("CLIP_BOXES");
            Shader.EnableKeyword("CLIP_NONE");
            Shader.DisableKeyword("RAY_ORIGIN");
        }
        void SetSection()
        {
            for (int i = 0; i < multiBoxes.Length; i++)
            {
                Transform boxTransform = multiBoxes[i].transform;
                //if (boxTransform.hasChanged) Debug.Log(i.ToString());
                Matrix4x4 m = Matrix4x4.TRS(boxTransform.position, boxTransform.rotation, Vector3.one);
                mxs[i] = m.inverse;
                boxScales[i] = boxTransform.localScale;
                Shader.SetGlobalMatrix("_WorldToObjectMatrix", m.inverse);
                Shader.SetGlobalVector("_SectionScale", transform.localScale);
            }
            Shader.SetGlobalMatrixArray("_WorldToObjectMatrixes", mxs);
            Shader.SetGlobalVectorArray("_SectionScales", boxScales);
        }

    }
}