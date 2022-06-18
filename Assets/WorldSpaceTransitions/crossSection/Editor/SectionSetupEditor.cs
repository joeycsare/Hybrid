 using UnityEngine;
using UnityEditor;


namespace WorldSpaceTransitions
{
    [CustomEditor(typeof(SectionSetup))]
    public class SectionSetupEditor : Editor
    {
        string shaderInfo = "";
        public override void OnInspectorGUI()
        {
            //DrawDefaultInspector(); 
            SectionSetup setupScript = (SectionSetup)target;
            setupScript.model = (GameObject)EditorGUILayout.ObjectField("model", setupScript.model, typeof(GameObject), true);
            if (setupScript.model)
            {
                if (setupScript.GetComponent<ISizedSection>() != null)
                {
                    //setupScript.boundsMode = EditorGUILayout.EnumPopup(setupScript.boundsMode, setupScript.boundsMode.GetNames());
                    setupScript.boundsMode = (BoundsOrientation)EditorGUILayout.EnumPopup("bounds mode:", setupScript.boundsMode);
                    setupScript.accurateBounds = EditorGUILayout.Toggle("accurate bounds", setupScript.accurateBounds);
                    GUILayout.Space(10);
                    GUILayout.BeginHorizontal();
                    GUILayout.FlexibleSpace();
                    if (GUILayout.Button("Recalculate bounds of " + setupScript.model.name))
                    {
                        setupScript.RecalculateBounds();
                    }
                    GUILayout.FlexibleSpace();
                    GUILayout.EndHorizontal();
                }
                //GUILayout.Space(10);
                GUILayout.BeginHorizontal();
                GUILayout.FlexibleSpace();
                if (GUILayout.Button("Check shaders on " + setupScript.model.name))
                {
                    shaderInfo = setupScript.CheckShaders();
                }
                GUILayout.FlexibleSpace();
                GUILayout.EndHorizontal();
                if (shaderInfo != "") GUILayout.Label(shaderInfo);
            }
            if (setupScript.shaderSubstitutes.Count > 0)
            {
                DrawDefaultInspector(); //draw shaderSubstitutes
                GUILayout.Space(10);
                GUILayout.BeginHorizontal();
                GUILayout.FlexibleSpace();

                if (GUILayout.Button("Create and Assign Section Materials"))
                {
                    setupScript.CreateSectionMaterials();
                }
                GUILayout.FlexibleSpace();
                GUILayout.EndHorizontal();
            }
        }
    }
}

